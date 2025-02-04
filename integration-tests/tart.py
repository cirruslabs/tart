import os
import subprocess
import sys
import tempfile


class Tart:
    def __init__(self):
        if "CIRRUS_WORKING_DIR" in os.environ:
            # Test on CI
            self.tart_home = tempfile.TemporaryDirectory(dir=os.environ.get("CIRRUS_WORKING_DIR"))
            self.cleanup = True

            # Link to the users cache to make things faster
            src = os.path.join(os.path.expanduser("~"), ".tart", "cache")
            dst = os.path.join(self.tart_home.name, "cache")
            os.symlink(src, dst)
        else:
            # Test on local machine 
            self.tart_home =  os.path.join(os.path.expanduser("~"), ".tart")
            self.cleanup = False

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.cleanup:
            self.tart_home.cleanup()

    def home(self) -> str:
        if self.cleanup:
            return self.tart_home.name
        else:
            return self.tart_home

    def run(self, args, pass_fds=()):
        env = os.environ.copy()
        env.update({"TART_HOME": self.home()})

        completed_process = subprocess.run(["tart"] + args, env=env, capture_output=True, pass_fds=pass_fds)

        completed_process.check_returncode()

        return completed_process.stdout.decode("utf-8"), completed_process.stderr.decode("utf-8")

    def run_async(self, args, pass_fds=()) -> subprocess.Popen:
        env = os.environ.copy()
        env.update({"TART_HOME": self.home()})
        return subprocess.Popen(["tart"] + args, env=env, pass_fds=pass_fds)
