import asyncio
import struct
import threading
from krita import Krita, Extension
from PyQt5.QtGui import QImage
from PyQt5.QtWidgets import QDialog, QVBoxLayout, QHBoxLayout, QLabel, QComboBox, QPushButton, QMessageBox
from .websockets.src.websockets import client

# Websocket port number
PORT_NUMBER = "44857"
# Script version (for compatibility checking pusposes)
VER_A = 0
VER_B = 5
# Script settings
DISABLED_LAYER_LABEL = "- none -" + ' ' * 40
SUBLAYER_LAYER_PREFIX = "  "
SEND_INTERVAL = 0.25

class NMInspectorClientExtension(Extension):
    """ Krita extension class """

    def __init__(self, parent):
        super().__init__(parent)
        self.config = {"document": None, "diff": None, "norm": None, "spec": None}
        self.starter = None
        self.bg_job = None

    def setup(self):
        pass

    def createActions(self, window):
        action = window.createAction("nm_inspector_client", "NM Inspector Client", "tools/scripts")
        action.triggered.connect(self.show_dialog)

    def show_dialog(self):
        self.starter = NMInspectorClientStarter(self.config)
        self.starter.accepted.connect(self.start_background_job)
        self.starter.show_dialog()

    def start_background_job(self):
        if self.bg_job:
            self.bg_job.stop()
            self.bg_job = None
        self.bg_job = NMInspectorBackgroundJob(self.config)

class NMInspectorClientStarter(QDialog):
    """ Dialog to choose layers from the active document. """

    def __init__(self, config):
        super().__init__()
        self.config = config
        self.document = None
        self.layer_list = []  # list of tuples: (display_name, node)

    def show_dialog(self):
        self.document = Krita.instance().activeDocument()
        if not self.document:
            QMessageBox.critical(self, "NM Inspector Client", "No active documents found!")
            return
        
        self.layer_list = self._build_layer_list()
        names = [name for name, _ in self.layer_list]

        self.setWindowTitle('NM Inspector Client')
        layout = QVBoxLayout()
        self.diff_combo = QComboBox()
        self.norm_combo = QComboBox()
        self.spec_combo = QComboBox()
        for combo, label in (
            (self.diff_combo, "Diffuse Texture Layer: "),
            (self.norm_combo, "Normal Map Layer: "),
            (self.spec_combo, "Specular Map Layer: ")
        ):
            h_layout = QHBoxLayout()
            h_layout.addWidget(QLabel(label))
            h_layout.addWidget(combo)
            layout.addLayout(h_layout)
            combo.addItems(names)

        connect_btn = QPushButton("Connect")
        connect_btn.clicked.connect(self.start_connection)
        cancel_btn = QPushButton("Cancel")
        cancel_btn.clicked.connect(self.reject)
        btn_box = QHBoxLayout()
        btn_box.addWidget(connect_btn)
        btn_box.addWidget(cancel_btn)
        layout.addLayout(btn_box)
        self.setLayout(layout)

        self._auto_select_layers()
        self.exec()

    def _build_layer_list(self):
        """ Returns a list of all layers as tuples: (display_name, node) """    
        layerlist = [(DISABLED_LAYER_LABEL, None)]
        if self.document:
            for node in reversed(self.document.topLevelNodes()):
                layerlist.extend(self._get_sub_layer_tree(node))
        return layerlist

    def _get_sub_layer_tree(self, node, depth=0):
        """ Recursively build a list of (display_name, node) pairs from the layer tree """
        display_name = f"{SUBLAYER_LAYER_PREFIX * depth}{node.name()}"
        result = [(display_name, node)]
        for child in reversed(node.childNodes()):
            result.extend(self._get_sub_layer_tree(child, depth + 1))
        return result

    def _auto_select_layers(self):
        """ This is just some garbage logic for layer auto selection in comboboxes """
        top_layers = self.document.topLevelNodes()
        # Helper: Find the first layer with the keyword match
        def find_layer_name(keyword, require_match=True):
            for node in top_layers:
                name = node.name()
                if keyword.lower() in name.lower():
                    if require_match:
                        return name
                else:
                    if not require_match:
                        return name
            return ""

        tmp_diff = find_layer_name("diff")
        tmp_norm = find_layer_name("norm")
        tmp_spec = find_layer_name("spec")
        cnt = len(top_layers)
        if cnt == 1:   # Only one layer: choose it for diffuse and clear normal.
            tmp_diff = top_layers[0].name()
            tmp_norm = ""
        elif cnt <= 3: # If one of diff/norm is missing, try to pick the missing one.
            if not tmp_diff and tmp_norm:
                tmp_diff = find_layer_name("norm", False)
            elif tmp_diff and not tmp_norm:
                tmp_norm = find_layer_name("diff", False)
        if cnt <= 2:
            tmp_spec = ""
        self.diff_combo.setCurrentText(tmp_diff)
        self.norm_combo.setCurrentText(tmp_norm)
        self.spec_combo.setCurrentText(tmp_spec)

    def start_connection(self):
        """ Update configs and close the dialog. """
        layers_dict = dict(self.layer_list)
        self.config["diff"] = layers_dict.get(self.diff_combo.currentText())
        self.config["norm"] = layers_dict.get(self.norm_combo.currentText())
        self.config["spec"] = layers_dict.get(self.spec_combo.currentText())
        self.config["document"] = self.document
        self.accept()


class NMInspectorBackgroundJob:
    """
    Background job that runs an asyncio loop in a separate thread, that
    connects to the NM Inspector through websocket and periodically sends layer image data.
    """
    def __init__(self, config):
        self.document = config["document"]
        self.layer_headers = [
            (config["diff"], ord("D")),
            (config["norm"], ord("N")),
            (config["spec"], ord("S"))
        ]
        self.websocket = None
        self.loop = None
        self.thread = threading.Thread(target=self._run_loop, daemon=True)
        self.thread.start()

    def _run_loop(self):
        """Create a new asyncio event loop and run the main loop coroutine."""
        self.loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self.loop)
        self.stop_event = asyncio.Event()
        self.loop.create_task(self._main_loop())
        try:
            self.loop.run_forever()
        finally:
            self.loop.run_until_complete(self.loop.shutdown_asyncgens())
            self.loop.close()

    async def _main_loop(self):
        """Start websocket connection and send layer data periodically."""
        while not self.stop_event.is_set():
            try: # Attempt to connect indefinitely until successful.
                self.websocket = await client.connect(
                    f"ws://localhost:{PORT_NUMBER}",
                    compression=None,
                    ping_interval=None
                )
                break # Exit loop if connection is successful.
            except Exception as e:
                await asyncio.sleep(1)
        if not self.websocket:
            return # Exit if stop_event was set before a connection could be made.
        
        try:
            await self._send_introduction()
            while not self.stop_event.is_set():
                data = await self._get_layer_data()
                if data is None:
                    break
                for header, payload in data:
                    await self.websocket.send(header)
                    await self.websocket.send(payload)
                # Krita doesn't have a refresh event, so we need to send our data with some interval.
                await asyncio.sleep(SEND_INTERVAL)
        except Exception as e:
            pass # print(f"Error in background job: {e}")
        finally:
            await self._disconnect()
            if self.loop is not None:
                self.loop.call_soon_threadsafe(self.loop.stop)

    async def _send_introduction(self):
        intro_data = struct.pack("<III", ord("V"), VER_A, VER_B)
        await self.websocket.send(intro_data)

    async def _get_layer_data(self):
        """
        Gather and return the image data from each configured layer.
        If the document is closed or data cannot be retrieved, return None.
        """
        if not self.document:
            return None
        results = []
        width = self.document.width()
        height = self.document.height()
        for layer, type_id in self.layer_headers:
            if layer:
                header = struct.pack("<III", type_id, width, height)
                # Retrieve the pixel data from the layer, preserving enabled sublayers, alpha, etc.
                pixel_data = layer.projectionPixelData(0, 0, width, height)
                # We need to create a QImage in order to swap RGB channels
                image = QImage(pixel_data, width, height, QImage.Format_RGBA8888).rgbSwapped()
                ptr = image.bits()
                if not ptr:
                    return None
                ptr.setsize(image.byteCount())
                byte_array = bytes(ptr)
                results.append((header, byte_array))
        return results

    async def _disconnect(self):
        """Disconnect the websocket if it's connected."""
        if self.websocket:
            try:
                await self.websocket.close()
            except Exception as e:
                print(f"Error closing websocket: {e}")
            self.websocket = None

    def stop(self):
        """Stop the background job cleanly."""
        if self.loop and not self.loop.is_closed():
            self.loop.call_soon_threadsafe(self.stop_event.set)
        self.thread.join()
