from krita import *
from .nm_inspector_client import NMInspectorClientExtension

Krita.instance().addExtension(NMInspectorClientExtension(Krita.instance()))
