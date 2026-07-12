#!/usr/bin/env python3
"""Mock greetd IPC server for testing. See docs/greetd-protocol.md for protocol details.

Valid passwords: password, 1234, admin
"""

import argparse
import json
import logging
import os
import struct
import time
from enum import Enum, auto
from socket import AF_UNIX, SOCK_STREAM, socket

PAYLOAD_LENGTH = 4  # bytes
SOCKET_PATH = "/tmp/mock_greetd.sock"
AUTH_FAIL_DELAY = 3.0  # seconds to wait on wrong password
VALID_PASSWORDS = ["password", "1234", "admin"]


class State(Enum):
    IDLE = auto()
    AWAITING_AUTH = auto()
    READY = auto()


log = logging.getLogger(__name__)

state = State.IDLE


def receive_and_send(conn: socket, simulate_delay: bool):
    global state

    data = conn.recv(PAYLOAD_LENGTH)
    payload_size = struct.unpack("=I", data)[0]

    data = conn.recv(payload_size)
    msg = data.decode("utf-8")
    log.info("recv <-- %s", msg)

    try:
        received_json = json.loads(msg)
        response = create_response(received_json, simulate_delay)
    except Exception as e:
        response = create_error_response("error", str(e))

    response_bytes = json.dumps(response).encode("utf-8")
    log.info("sent --> %s", response)
    _ = conn.send(struct.pack("=I", len(response_bytes)))
    _ = conn.send(response_bytes)


def create_response(request: dict[str, str], simulate_delay: bool) -> dict[str, str]:
    global state

    request_type = request.get("type")

    # Validate state transitions
    match (state, request_type):
        case (State.IDLE, "create_session" | "cancel_session"):
            pass
        case (State.IDLE, _):
            return create_error_response(
                "error",
                f"Unexpected {request_type} in state {state.name}: no session created",
            )
        case (State.AWAITING_AUTH, "post_auth_message_response" | "cancel_session"):
            pass
        case (State.AWAITING_AUTH, _):
            return create_error_response(
                "error",
                f"Unexpected {request_type} in state {state.name}: must answer auth or cancel",
            )
        case (State.READY, "start_session" | "cancel_session"):
            pass
        case (State.READY, _):
            return create_error_response(
                "error",
                f"Unexpected {request_type} in state {state.name}: must start or cancel session",
            )

    # Handle request
    match request:
        case {"type": "create_session", "username": "error"}:
            return create_error_response("error", "random error")
        case {"type": "create_session", "username": "success"}:
            state = State.READY
            log.debug("state -> %s", state.name)
            return create_success_response()
        case {"type": "create_session"}:
            state = State.AWAITING_AUTH
            log.debug("state -> %s", state.name)
            return create_auth_response("secret", "Password:")
        case {"type": "post_auth_message_response", "response": response} if (
            response not in VALID_PASSWORDS
        ):
            if simulate_delay:
                log.info("Simulating %ss delay for wrong password...", AUTH_FAIL_DELAY)
                time.sleep(AUTH_FAIL_DELAY)
            state = State.IDLE
            log.debug("state -> %s", state.name)
            return create_error_response("auth_error", "Incorrect password")
        case {"type": "post_auth_message_response"}:
            state = State.READY
            log.debug("state -> %s", state.name)
            return create_success_response()
        case {"type": "start_session"}:
            state = State.IDLE
            log.debug("state -> %s", state.name)
            return create_success_response()
        case {"type": "cancel_session"}:
            state = State.IDLE
            log.debug("state -> %s", state.name)
            return create_success_response()
        case _:
            return create_error_response("error", "Unknown request type")


def create_success_response():
    return {"type": "success"}


def create_error_response(error_type: str, description: str):
    return {"type": "error", "error_type": error_type, "description": description}


def create_auth_response(type: str, message: str):
    return {"type": "auth_message", "auth_message_type": type, "auth_message": message}


def run_server(simulate_delay: bool):
    if os.path.exists(SOCKET_PATH):
        os.remove(SOCKET_PATH)

    server = socket(AF_UNIX, SOCK_STREAM)
    server.bind(SOCKET_PATH)
    server.listen(1)

    log.info("Listening on %s", SOCKET_PATH)
    if simulate_delay:
        log.info("Auth failure delay: %ss (disable with --no-delay)", AUTH_FAIL_DELAY)
    else:
        log.info("Auth failure delay: disabled")

    try:
        while True:
            conn, _ = server.accept()
            log.debug("Connected")

            receive_and_send(conn, simulate_delay)

            conn.close()
    except KeyboardInterrupt:
        log.info("KeyboardInterrupt")
    except Exception as e:
        log.error("Error: %s", e)
    finally:
        server.close()
        if os.path.exists(SOCKET_PATH):
            os.remove(SOCKET_PATH)
        log.info("Closed")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Mock greetd server")
    parser.add_argument(
        "--no-delay",
        action="store_true",
        help="Disable the simulated delay on wrong password",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Enable debug logging",
    )
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        datefmt="%H:%M:%S",
    )

    run_server(simulate_delay=not args.no_delay)
