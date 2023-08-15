import tempfile
import os
import subprocess


class Tart:
    def __init__(self):
        self.tmp_dir = tempfile.TemporaryDirectory(dir=os.environ.get("CIRRUS_WORKING_DIR"))

        # Link to the users cache to make things faster
        src = os.path.join(os.path.expanduser("~"), ".tart", "cache")
        dst = os.path.join(self.tmp_dir.name, "cache")
        os.symlink(src, dst)

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.tmp_dir.cleanup()

    def home(self) -> str:
        return self.tmp_dir.name

    def run(self, args):
        env = os.environ.copy()
        env.update({"TART_HOME": self.tmp_dir.name})

        completed_process = subprocess.run(["tart"] + args, env=env, capture_output=True)

        completed_process.check_returncode()

        return completed_process.stdout.decode("utf-8"), completed_process.stderr.decode("utf-8")

    def run_async(self, args) -> subprocess.Popen:
        env = os.environ.copy()
        env.update({"TART_HOME": self.tmp_dir.name})

        return subprocess.Popen(["tart"] + args, env=env)
