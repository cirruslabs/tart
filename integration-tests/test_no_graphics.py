import json
import os
import subprocess
import time
import uuid

import pytest


def check_json_format(tart, vm_name, running, noGraphics, expected):
    stdout, _ = tart.run(["get", vm_name, "--format", "json"])
    vm_info = json.loads(stdout)
    actual_running = vm_info["Running"]
    assert actual_running is running, f"Running is {actual_running}, expected {running}"
    assert vm_info.get("NoGraphics") is noGraphics, expected

def check_text_format(tart, vm_name, running, noGraphics, expected):
    stdout, _ = tart.run(["get", vm_name, "--format", "text"])
    assert "NoGraphics" in stdout, "NoGraphics field should be present in text output"

    # Text format is tab-separated with headers in first line
    lines = stdout.strip().split('\n')
    if len(lines) >= 2:
        headers = lines[0].split()
        values = lines[1].split()
        info_dict = dict(zip(headers, values))
    else:
        info_dict = {}

    # Convert "stopped" to false for Running field
    actual_running = info_dict.get("State") != "stopped"
    assert actual_running == running, f"Expected Running={running}, got State={actual_running}"
    assert info_dict.get("NoGraphics") == noGraphics, expected

@pytest.mark.skipif(os.environ.get("CI") == "true", reason="Normal graphics mode doesn't work in CI")
def test_no_graphics_normal(tart):
    _test_no_graphics_impl(tart, [], False)

def test_no_graphics_disabled(tart):
    _test_no_graphics_impl(tart, ["--no-graphics"], True)

def _test_no_graphics_impl(tart, graphics_mode, expected_no_graphics):
    # Create a test VM (use Linux VM for faster tests)
    vm_name = f"integration-test-no-graphics-{uuid.uuid4()}"
    tart.run(["pull", "ghcr.io/cirruslabs/debian:latest"])
    tart.run(["clone", "ghcr.io/cirruslabs/debian:latest", vm_name])

    # Test 1: VM not running - NoGraphics should be None in json format
    check_json_format(tart, vm_name, False, None, "NoGraphics should be None when VM is not running")

    # Test 2: VM not running - NoGraphics should be NULL in text format
    check_text_format(tart, vm_name, False, "NULL", "NoGraphics should be NULL when VM is not running")

    # Run VM with specified graphics mode
    tart_run_process = tart.run_async(["run"] + graphics_mode + [vm_name])
    time.sleep(3)  # Give VM time to start

    # Test 3: VM running - NoGraphics should be XX in json format
    check_json_format(tart, vm_name, True, expected_no_graphics, f"NoGraphics should be {expected_no_graphics} (JSON) when VM is running")

    # Test 4: VM running - NoGraphics should be XX in text format
    check_text_format(tart, vm_name, True, str(expected_no_graphics).lower(), f"NoGraphics should be {expected_no_graphics} (TEXT) when VM is running")
