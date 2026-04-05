#!/usr/bin/env python3
"""
apfel-debug-tools - MCP debug server for apfel-gui

Provides simple tools for testing and debugging MCP tool calling.
Zero dependencies beyond Python 3 stdlib.

Transport: stdio (JSON-RPC 2.0)
Protocol: MCP 2025-06-18
"""

import json
import platform
import socket
import sys
from datetime import datetime, timezone

PROTOCOL_VERSION = "2025-06-18"
SERVER_NAME = "apfel-debug-tools"
SERVER_VERSION = "1.0.0"

TOOLS = [
    {
        "name": "echo",
        "description": "Returns the input text unchanged. Use for testing tool call round-trips.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "text": {"type": "string", "description": "Text to echo back"}
            },
            "required": ["text"]
        }
    },
    {
        "name": "timestamp",
        "description": "Returns the current date and time as ISO 8601 UTC.",
        "inputSchema": {
            "type": "object",
            "properties": {}
        }
    },
    {
        "name": "system_info",
        "description": "Returns system information: hostname, macOS version, Python version.",
        "inputSchema": {
            "type": "object",
            "properties": {}
        }
    },
]


def execute(name, args):
    """Execute a tool by name."""
    if name == "echo":
        text = args.get("text", "")
        if not text:
            # Tolerate model sending text under different keys
            for v in args.values():
                if isinstance(v, str):
                    text = v
                    break
        return text if text else "(empty)"

    elif name == "timestamp":
        return datetime.now(timezone.utc).isoformat()

    elif name == "system_info":
        return json.dumps({
            "hostname": socket.gethostname(),
            "system": platform.system(),
            "version": platform.mac_ver()[0] or platform.version(),
            "machine": platform.machine(),
            "python": platform.python_version(),
        }, indent=2)

    return f"Error: unknown tool '{name}'"


def read_message():
    line = sys.stdin.readline()
    if not line:
        return None
    return json.loads(line.strip())


def send(msg):
    sys.stdout.write(json.dumps(msg, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def respond(msg_id, result):
    send({"jsonrpc": "2.0", "id": msg_id, "result": result})


def error(msg_id, code, message):
    send({"jsonrpc": "2.0", "id": msg_id, "error": {"code": code, "message": message}})


def handle(msg):
    method = msg.get("method", "")
    msg_id = msg.get("id")
    params = msg.get("params", {})

    if method == "initialize":
        respond(msg_id, {
            "protocolVersion": PROTOCOL_VERSION,
            "capabilities": {"tools": {}},
            "serverInfo": {"name": SERVER_NAME, "version": SERVER_VERSION}
        })
    elif method == "notifications/initialized":
        pass
    elif method == "tools/list":
        respond(msg_id, {"tools": TOOLS})
    elif method == "tools/call":
        name = params.get("name", "")
        args = params.get("arguments", {})
        tool_names = {t["name"] for t in TOOLS}
        if name in tool_names:
            result = execute(name, args)
            respond(msg_id, {
                "content": [{"type": "text", "text": result}],
                "isError": result.startswith("Error:")
            })
        else:
            error(msg_id, -32602, f"Unknown tool: {name}")
    elif method == "ping":
        respond(msg_id, {})
    elif msg_id is not None:
        error(msg_id, -32601, f"Method not found: {method}")


def main():
    while True:
        msg = read_message()
        if msg is None:
            break
        handle(msg)


if __name__ == "__main__":
    main()
