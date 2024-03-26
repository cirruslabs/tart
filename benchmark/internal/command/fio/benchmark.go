package fio

type Benchmark struct {
	Name    string
	Command string
}

var benchmarks = []Benchmark{
	{
		Name: "Random writing of 1MB",
		Command: "fio --rw randwrite --runtime 10 --time_based --unlink 1 --output-format json " +
			"--size 1MB --name unnamed",
	},
	{
		Name: "Random writing of 10MB",
		Command: "fio --rw randwrite --runtime 10 --time_based --unlink 1 --output-format json " +
			"--size 10MB --name unnamed",
	},
	{
		Name: "Random writing of 100MB",
		Command: "fio --rw randwrite --runtime 10 --time_based --unlink 1 --output-format json " +
			"--size 100MB --name unnamed",
	},
	{
		Name: "Random writing of 1000MB",
		Command: "fio --rw randwrite --runtime 10 --time_based --unlink 1 --output-format json " +
			"--size 1000MB --name unnamed",
	},
}
