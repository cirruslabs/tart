package xcode

type Benchmark struct {
	Name    string
	Command string
}

var benchmarks = []Benchmark{
	{
		Name:    "XcodeBenchmark (d869315)",
		Command: "git clone https://github.com/devMEremenko/XcodeBenchmark.git && cd XcodeBenchmark && git reset --hard d86931529ada1df2a1c6646dd85958c360954065 && xcrun simctl list && sh benchmark.sh",
	},
}
