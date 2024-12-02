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
		Command: "fio --name=random-write --ioengine=posixaio --rw=randwrite --bs=4k --size=4g --numjobs=1 --iodepth=1 --runtime=60 --time_based --end_fsync=1" +
			" --output-format json --unlink 1",
	},
	{
		// Ars Technica's "16 parallel 64KiB random write processes" test[1]
		// with JSON outpu, created file cleanup and group reporting (for
		// easier analysis)
		//
		// [1]: https://arstechnica.com/gadgets/2020/02/how-fast-are-your-disks-find-out-the-open-source-way-with-fio/
		Name: "16 parallel 64KiB random write processes",
		Command: "fio --name=random-write --ioengine=posixaio --rw=randwrite --bs=64k --size=256m --numjobs=16 --iodepth=16 --runtime=60 --time_based --end_fsync=1" +
			" --output-format json --unlink 1 --group_reporting",
	},
	{
		// Ars Technica's "16 parallel 64KiB random write processes" test[1]
		// with JSON output, created file cleanup and reduced file I/O size
		// from 16 to 10 GB to avoid "No space left on device".
		//
		// [1]: https://arstechnica.com/gadgets/2020/02/how-fast-are-your-disks-find-out-the-open-source-way-with-fio/
		Name: "Single 1MiB random write process",
		Command: "fio --name=random-write --ioengine=posixaio --rw=randwrite --bs=1m --size=10g --numjobs=1 --iodepth=1 --runtime=60 --time_based --end_fsync=1" +
			" --output-format json --unlink 1",
	},
}
