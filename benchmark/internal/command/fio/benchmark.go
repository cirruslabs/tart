package fio

type Benchmark struct {
	Name    string
	Command string
}

var benchmarks = []Benchmark{
	{
		// Ars Technica's "Single 4KiB random write process" test[1]
		// with JSON output and created file cleanup
		//
		// [1]: https://arstechnica.com/gadgets/2020/02/how-fast-are-your-disks-find-out-the-open-source-way-with-fio/
		Name: "Single 4KiB random write process",
		Command: "fio --name=benchmark --ioengine=posixaio --rw=randwrite --bs=4k --size=4g --numjobs=1 --iodepth=1 --runtime=60 --time_based --end_fsync=1" +
			" --output-format json --unlink 1",
	},
	{
		// Ars Technica's "16 parallel 64KiB random write processes" test[1]
		// with JSON outpu, created file cleanup and group reporting (for
		// easier analysis)
		//
		// [1]: https://arstechnica.com/gadgets/2020/02/how-fast-are-your-disks-find-out-the-open-source-way-with-fio/
		Name: "16 parallel 64KiB random write processes",
		Command: "fio --name=benchmark --ioengine=posixaio --rw=randwrite --bs=64k --size=256m --numjobs=16 --iodepth=16 --runtime=60 --time_based --end_fsync=1" +
			" --output-format json --unlink 1 --group_reporting",
	},
	{
		// Ars Technica's "16 parallel 64KiB random write processes" test[1]
		// with JSON output, created file cleanup and reduced file I/O size
		// from 16 to 10 GB to avoid "No space left on device".
		//
		// [1]: https://arstechnica.com/gadgets/2020/02/how-fast-are-your-disks-find-out-the-open-source-way-with-fio/
		Name: "Single 1MiB random write process",
		Command: "fio --name=benchmark --ioengine=posixaio --rw=randwrite --bs=1m --size=10g --numjobs=1 --iodepth=1 --runtime=60 --time_based --end_fsync=1" +
			" --output-format json --unlink 1",
	},
	{
		// Oracle's "Test random read/writes" (in IOPS Performance Tests[1]) category
		// with JSON output, created file cleanup, without ETA newline, without custom
		// file path, with file I/O size reduced from 500GB to 2GB to prevent
		// "No space left on device" and with posixaio instead of libaio.
		//
		// [1]: https://docs.oracle.com/en-us/iaas/Content/Block/References/samplefiocommandslinux.htm#FIO_Commands
		Name: "Random reads/writes (4k)",
		Command: "fio --name=benchmark --size=2GB --direct=1 --rw=randrw --bs=4k --ioengine=posixaio --iodepth=256 --runtime=120 --numjobs=4 --time_based --group_reporting" +
			" --output-format json --unlink 1",
	},
	{
		// Oracle's "Test random read/writes" (in Throughput Performance Tests[1]) category
		// with JSON output, created file cleanup, without ETA newline, without custom
		// file path, with file I/O size reduced from 500GB to 2GB to prevent
		// "No space left on device" and with posixaio instead of libaio.
		//
		// [1]: https://docs.oracle.com/en-us/iaas/Content/Block/References/samplefiocommandslinux.htm#Throughput_Performance_Tests
		Name: "Random reads/writes (64k)",
		Command: "fio --name=benchmark --size=2GB --direct=1 --rw=randrw --bs=64k --ioengine=posixaio --iodepth=64 --runtime=120 --numjobs=4 --time_based --group_reporting" +
			" --output-format json --unlink 1",
	},
	{
		// RedHat's "How can I test to see if my environment is fast enough for etcd"[1]
		// with custom name
		//
		// [1]: https://access.redhat.com/solutions/5726511
		Name: "sync test",
		Command: "mkdir -p test-data && fio --name=benchmark --rw=write --ioengine=sync --fdatasync=1 --directory=test-data --size=22m --bs=2300" +
			" --output-format json --unlink 1",
	},
}
