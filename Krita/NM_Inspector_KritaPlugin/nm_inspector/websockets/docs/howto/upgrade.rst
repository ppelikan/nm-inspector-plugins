Upgrade to the new :mod:`asyncio` implementation
================================================

.. currentmodule:: websockets

The new :mod:`asyncio` implementation is a rewrite of the original
implementation of websockets.

It provides a very similar API. However, there are a few differences.

The recommended upgrade process is:

1. Make sure that your application doesn't use any `deprecated APIs`_. If it
   doesn't raise any warnings, you can skip this step.
2. Check if your application depends on `missing features`_. If it does, you
   should stick to the original implementation until they're added.
3. `Update import paths`_. For straightforward usage of websockets, this could
   be the only step you need to take. Upgrading could be transparent.
4. `Review API changes`_ and adapt your application to preserve its current
   functionality or take advantage of improvements in the new implementation.

In the interest of brevity, only :func:`~asyncio.client.connect` and
:func:`~asyncio.server.serve` are discussed below but everything also applies
to :func:`~asyncio.client.unix_connect` and :func:`~asyncio.server.unix_serve`
respectively.

.. admonition:: What will happen to the original implementation?
    :class: hint

    The original implementation is now considered legacy.

    The next steps are:

    1. Deprecating it once the new implementation reaches feature parity.
    2. Maintaining it for five years per the :ref:`backwards-compatibility
       policy <backwards-compatibility policy>`.
    3. Removing it. This is expected to happen around 2030.

.. _deprecated APIs:

Deprecated APIs
---------------

Here's the list of deprecated behaviors that the original implementation still
supports and that the new implementation doesn't reproduce.

If you're seeing a :class:`DeprecationWarning`, follow upgrade instructions from
the release notes of the version in which the feature was deprecated.

* The ``path`` argument of connection handlers — unnecessary since :ref:`10.1`
  and deprecated in :ref:`13.0`.
* The ``loop`` and ``legacy_recv`` arguments of :func:`~legacy.client.connect`
  and :func:`~legacy.server.serve`, which were removed — deprecated in
  :ref:`10.0`.
* The ``timeout`` and ``klass`` arguments of :func:`~legacy.client.connect` and
  :func:`~legacy.server.serve`, which were renamed to ``close_timeout`` and
  ``create_protocol`` — deprecated in :ref:`7.0` and :ref:`3.4` respectively.
* An empty string in the ``origins`` argument of :func:`~legacy.server.serve` —
  deprecated in :ref:`7.0`.
* The ``host``, ``port``, and ``secure`` attributes of connections — deprecated
  in :ref:`8.0`.

.. _missing features:

Missing features
----------------

.. admonition:: All features listed below will be provided in a future release.
    :class: tip

    If your application relies on one of them, you should stick to the original
    implementation until the new implementation supports it in a future release.

HTTP Basic Authentication
.........................

On the server side, :func:`~asyncio.server.serve` doesn't provide HTTP Basic
Authentication yet.

For the avoidance of doubt, on the client side, :func:`~asyncio.client.connect`
performs HTTP Basic Authentication.

Following redirects
...................

The new implementation of :func:`~asyncio.client.connect` doesn't follow HTTP
redirects yet.

Automatic reconnection
......................

The new implementation of :func:`~asyncio.client.connect` doesn't provide
automatic reconnection yet.

In other words, the following pattern isn't supported::

    from websockets.asyncio.client import connect

    async for websocket in connect(...):  # this doesn't work yet
        ...

.. _Update import paths:

Import paths
------------

For context, the ``websockets`` package is structured as follows:

* The new implementation is found in the ``websockets.asyncio`` package.
* The original implementation was moved to the ``websockets.legacy`` package.
* The ``websockets`` package provides aliases for convenience.
* The ``websockets.client`` and ``websockets.server`` packages provide aliases
  for backwards-compatibility with earlier versions of websockets.
* Currently, all aliases point to the original implementation. In the future,
  they will point to the new implementation or they will be deprecated.

To upgrade to the new :mod:`asyncio` implementation, change import paths as
shown in the tables below.

.. |br| raw:: html

    <br/>

Client APIs
...........

+-------------------------------------------------------------------+-----------------------------------------------------+
| Legacy :mod:`asyncio` implementation                              | New :mod:`asyncio` implementation                   |
+===================================================================+=====================================================+
| ``websockets.connect()``                                     |br| | :func:`websockets.asyncio.client.connect`           |
| ``websockets.client.connect()``                              |br| |                                                     |
| :func:`websockets.legacy.client.connect`                          |                                                     |
+-------------------------------------------------------------------+-----------------------------------------------------+
| ``websockets.unix_connect()``                                |br| | :func:`websockets.asyncio.client.unix_connect`      |
| ``websockets.client.unix_connect()``                         |br| |                                                     |
| :func:`websockets.legacy.client.unix_connect`                     |                                                     |
+-------------------------------------------------------------------+-----------------------------------------------------+
| ``websockets.WebSocketClientProtocol``                       |br| | :class:`websockets.asyncio.client.ClientConnection` |
| ``websockets.client.WebSocketClientProtocol``                |br| |                                                     |
| :class:`websockets.legacy.client.WebSocketClientProtocol`         |                                                     |
+-------------------------------------------------------------------+-----------------------------------------------------+

Server APIs
...........

+-------------------------------------------------------------------+-----------------------------------------------------+
| Legacy :mod:`asyncio` implementation                              | New :mod:`asyncio` implementation                   |
+===================================================================+=====================================================+
| ``websockets.serve()``                                       |br| | :func:`websockets.asyncio.server.serve`             |
| ``websockets.server.serve()``                                |br| |                                                     |
| :func:`websockets.legacy.server.serve`                            |                                                     |
+-------------------------------------------------------------------+-----------------------------------------------------+
| ``websockets.unix_serve()``                                  |br| | :func:`websockets.asyncio.server.unix_serve`        |
| ``websockets.server.unix_serve()``                           |br| |                                                     |
| :func:`websockets.legacy.server.unix_serve`                       |                                                     |
+-------------------------------------------------------------------+-----------------------------------------------------+
| ``websockets.WebSocketServer``                               |br| | :class:`websockets.asyncio.server.Server`           |
| ``websockets.server.WebSocketServer``                        |br| |                                                     |
| :class:`websockets.legacy.server.WebSocketServer`                 |                                                     |
+-------------------------------------------------------------------+-----------------------------------------------------+
| ``websockets.WebSocketServerProtocol``                       |br| | :class:`websockets.asyncio.server.ServerConnection` |
| ``websockets.server.WebSocketServerProtocol``                |br| |                                                     |
| :class:`websockets.legacy.server.WebSocketServerProtocol`         |                                                     |
+-------------------------------------------------------------------+-----------------------------------------------------+
| ``websockets.broadcast``                                     |br| | :func:`websockets.asyncio.server.broadcast`         |
| :func:`websockets.legacy.server.broadcast()`                      |                                                     |
+-------------------------------------------------------------------+-----------------------------------------------------+
| ``websockets.BasicAuthWebSocketServerProtocol``              |br| | *not available yet*                                 |
| ``websockets.auth.BasicAuthWebSocketServerProtocol``         |br| |                                                     |
| :class:`websockets.legacy.auth.BasicAuthWebSocketServerProtocol`  |                                                     |
+-------------------------------------------------------------------+-----------------------------------------------------+
| ``websockets.basic_auth_protocol_factory()``                 |br| | *not available yet*                                 |
| ``websockets.auth.basic_auth_protocol_factory()``            |br| |                                                     |
| :func:`websockets.legacy.auth.basic_auth_protocol_factory`        |                                                     |
+-------------------------------------------------------------------+-----------------------------------------------------+

.. _Review API changes:

API changes
-----------

Controlling UTF-8 decoding
..........................

The new implementation of the :meth:`~asyncio.connection.Connection.recv` method
provides the ``decode`` argument to control UTF-8 decoding of messages. This
didn't exist in the original implementation.

If you're calling :meth:`~str.encode` on a :class:`str` object returned by
:meth:`~asyncio.connection.Connection.recv`, using ``decode=False`` and removing
:meth:`~str.encode` saves a round-trip of UTF-8 decoding and encoding for text
messages.

You can also force UTF-8 decoding of binary messages with ``decode=True``. This
is rarely useful and has no performance benefits over decoding a :class:`bytes`
object returned by :meth:`~asyncio.connection.Connection.recv`.

Receiving fragmented messages
.............................

The new implementation provides the
:meth:`~asyncio.connection.Connection.recv_streaming` method for receiving a
fragmented message frame by frame. There was no way to do this in the original
implementation.

Depending on your use case, adopting this method may improve performance when
streaming large messages. Specifically, it could reduce memory usage.

Customizing the opening handshake
.................................

On the client side, if you're adding headers to the handshake request sent by
:func:`~legacy.client.connect` with the ``extra_headers`` argument, you must
rename it to ``additional_headers``.

On the server side, if you're customizing how :func:`~legacy.server.serve`
processes the opening handshake with the ``process_request``, ``extra_headers``,
or ``select_subprotocol``, you must update your code. ``process_response`` and
``select_subprotocol`` have new signatures; ``process_response`` replaces
``extra_headers`` and provides more flexibility.

``process_request``
~~~~~~~~~~~~~~~~~~~

The signature of ``process_request`` changed. This is easiest to illustrate with
an example::

    import http

    # Original implementation

    def process_request(path, request_headers):
        return http.HTTPStatus.OK, [], b"OK\n"

    serve(..., process_request=process_request, ...)

    # New implementation

    def process_request(connection, request):
        return connection.respond(http.HTTPStatus.OK, "OK\n")

    serve(..., process_request=process_request, ...)

``connection`` is always available in ``process_request``. In the original
implementation, you had to write a subclass of
:class:`~legacy.server.WebSocketServerProtocol` and pass it in the
``create_protocol`` argument to make the connection object available in a
``process_request`` method. This pattern isn't useful anymore; you can replace
it with a ``process_request`` function or coroutine.

``path`` and ``headers`` are available as attributes of the ``request`` object.

``process_response``
~~~~~~~~~~~~~~~~~~~~

``process_request`` replaces ``extra_headers`` and provides more flexibility.
In the most basic case, you would adapt your code as follows::

    # Original implementation

    serve(..., extra_headers=HEADERS, ...)

    # New implementation

    def process_response(connection, request, response):
        response.headers.update(HEADERS)
        return response

    serve(..., process_response=process_response, ...)

``connection`` is always available in ``process_response``, similar to
``process_request``. In the original implementation, there was no way to make
the connection object available.

In addition, the ``request`` and ``response`` objects are available, which
enables a broader range of use cases (e.g., logging) and makes
``process_response`` more useful than ``extra_headers``.

``select_subprotocol``
~~~~~~~~~~~~~~~~~~~~~~

The signature of ``select_subprotocol`` changed. Here's an example::

    # Original implementation

    def select_subprotocol(client_subprotocols, server_subprotocols):
        if "chat" in client_subprotocols:
            return "chat"

    # New implementation

    def select_subprotocol(connection, subprotocols):
        if "chat" in subprotocols
            return "chat"

    serve(..., select_subprotocol=select_subprotocol, ...)

``connection`` is always available in ``select_subprotocol``. This brings the
same benefits as in ``process_request``. It may remove the need to subclass of
:class:`~legacy.server.WebSocketServerProtocol`.

The ``subprotocols`` argument contains the list of subprotocols offered by the
client. The list of subprotocols supported by the server was removed because
``select_subprotocols`` already knows which subprotocols it may select and under
which conditions.

Arguments of :func:`~asyncio.client.connect` and :func:`~asyncio.server.serve`
..............................................................................

``ws_handler`` → ``handler``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The first argument of :func:`~asyncio.server.serve` is now called ``handler``
instead of ``ws_handler``. It's usually passed as a positional argument, making
this change transparent. If you're passing it as a keyword argument, you must
update its name.

``create_protocol`` → ``create_connection``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The keyword argument of :func:`~asyncio.server.serve` for customizing the
creation of the connection object is now called ``create_connection`` instead of
``create_protocol``. It must return a :class:`~asyncio.server.ServerConnection`
instead of a :class:`~legacy.server.WebSocketServerProtocol`.

If you were customizing connection objects, you should check the new
implementation and possibly redo your customization. Keep in mind that the
changes to ``process_request`` and ``select_subprotocol`` remove most use cases
for ``create_connection``.

``max_queue``
~~~~~~~~~~~~~

The ``max_queue`` argument of :func:`~asyncio.client.connect` and
:func:`~asyncio.server.serve` has a new meaning but achieves a similar effect.

It is now the high-water mark of a buffer of incoming frames. It defaults to 16
frames. It used to be the size of a buffer of incoming messages that refilled as
soon as a message was read. It used to default to 32 messages.

This can make a difference when messages are fragmented in several frames. In
that case, you may want to increase ``max_queue``. If you're writing a high
performance server and you know that you're receiving fragmented messages,
probably you should adopt :meth:`~asyncio.connection.Connection.recv_streaming`
and optimize the performance of reads again. In all other cases, given how
uncommon fragmentation is, you shouldn't worry about this change.

``read_limit``
~~~~~~~~~~~~~~

The ``read_limit`` argument doesn't exist in the new implementation because it
doesn't buffer data received from the network in a
:class:`~asyncio.StreamReader`. With a better design, this buffer could be
removed.

The buffer of incoming frames configured by ``max_queue`` is the only read
buffer now.

``write_limit``
~~~~~~~~~~~~~~~

The ``write_limit`` argument of :func:`~asyncio.client.connect` and
:func:`~asyncio.server.serve` defaults to 32 KiB instead of 64 KiB.

Attributes of connections
.........................

``path``, ``request_headers`` and ``response_headers``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The :attr:`~legacy.protocol.WebSocketCommonProtocol.path`,
:attr:`~legacy.protocol.WebSocketCommonProtocol.request_headers` and
:attr:`~legacy.protocol.WebSocketCommonProtocol.response_headers` properties are
replaced by :attr:`~asyncio.connection.Connection.request` and
:attr:`~asyncio.connection.Connection.response`, which provide a ``headers``
attribute.

If your code relies on them, you can replace::

    connection.path
    connection.request_headers
    connection.response_headers

with::

    connection.request.path
    connection.request.headers
    connection.response.headers

``open`` and ``closed``
~~~~~~~~~~~~~~~~~~~~~~~

The :attr:`~legacy.protocol.WebSocketCommonProtocol.open` and
:attr:`~legacy.protocol.WebSocketCommonProtocol.closed` properties are removed.
Using them was discouraged.

Instead, you should call :meth:`~asyncio.connection.Connection.recv` or
:meth:`~asyncio.connection.Connection.send` and handle
:exc:`~exceptions.ConnectionClosed` exceptions.

If your code relies on them, you can replace::

    connection.open
    connection.closed

with::

    from websockets.protocol import State

    connection.state is State.OPEN
    connection.state is State.CLOSED
