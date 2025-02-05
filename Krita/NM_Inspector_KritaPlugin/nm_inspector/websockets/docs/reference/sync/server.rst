Server (:mod:`threading`)
=========================

.. automodule:: websockets.sync.server

Creating a server
-----------------

.. autofunction:: serve

.. autofunction:: unix_serve

Running a server
----------------

.. autoclass:: Server

    .. automethod:: serve_forever

    .. automethod:: shutdown

    .. automethod:: fileno

Using a connection
------------------

.. autoclass:: ServerConnection

    .. automethod:: __iter__

    .. automethod:: recv

    .. automethod:: recv_streaming

    .. automethod:: send

    .. automethod:: close

    .. automethod:: ping

    .. automethod:: pong

    .. automethod:: respond

    WebSocket connection objects also provide these attributes:

    .. autoattribute:: id

    .. autoattribute:: logger

    .. autoproperty:: local_address

    .. autoproperty:: remote_address

    The following attributes are available after the opening handshake,
    once the WebSocket connection is open:

    .. autoattribute:: request

    .. autoattribute:: response

    .. autoproperty:: subprotocol
