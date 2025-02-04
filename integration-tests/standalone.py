import test_devices
import tart
import logging

FORMAT = "{asctime} - {levelname} - {name}:{message}"
logging.basicConfig(filename='/dev/stdout', format=FORMAT, datefmt="%Y-%m-%d %H:%M", style="{", level=logging.INFO)

log = logging.getLogger(__name__)

onLinux = test_devices.TestVirtioDevicesOnLinux()
onMac = test_devices.TestVirtioDevicesOnMacOS()
tart = tart.Tart()

log.info("Running standalone tests...")

log.info("\n\n=====================================================================================================")
log.info("test_virtio_bind on Linux...")
onLinux.test_virtio_bind(tart)

log.info("\n\n=====================================================================================================")
log.info("test_virtio_http on Linux...")
onLinux.test_virtio_http(tart)

log.info("\n\n=====================================================================================================")
log.info("test_virtio_tcp on Linux...")
onLinux.test_virtio_tcp(tart)

log.info("\n\n=====================================================================================================")
log.info("test_virtio_connect on Linux...")
onLinux.test_virtio_connect(tart)

log.info("\n\n=====================================================================================================")
log.info("test_virtio_pipe on Linux...")
onLinux.test_virtio_pipe(tart)

log.info("\n\n=====================================================================================================")
log.info("test_console_socket on Linux...")
onLinux.test_console_socket(tart)

log.info("\n\n=====================================================================================================")
log.info("test_console_pipe on Linux...")
onLinux.test_console_pipe(tart)

log.info("\n\n=====================================================================================================")
log.info("test_virtio_bind on MacOS...")
onMac.test_virtio_bind(tart)

log.info("\n\n=====================================================================================================")
log.info("test_virtio_http on MacOS...")
onMac.test_virtio_http(tart)

log.info("\n\n=====================================================================================================")
log.info("test_virtio_tcp on MacOS...")
onMac.test_virtio_tcp(tart)

log.info("\n\n=====================================================================================================")
log.info("test_virtio_connect on MacOS...")
onMac.test_virtio_connect(tart)

log.info("\n\n=====================================================================================================")
log.info("test_virtio_pipe on MacOS...")
onMac.test_virtio_pipe(tart)

log.info("\n\n=====================================================================================================")
log.info("test_console_socket on MacOS...")
onMac.test_console_socket(tart)

log.info("\n\n=====================================================================================================")
log.info("test_console_pipe on MacOS...")
onMac.test_console_pipe(tart)

