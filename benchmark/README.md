# Benchmark

Tart comes with a Golang-based benchmarking utility that allows one to easily compare host and guest performance.

Currently, only Flexible I/O tester workloads are supported. To run them, [install Golang](https://go.dev/) and run the following command from this (`benchmark/`) directory:

```shell
go run cmd/main.go fio
```

You can also enable the debugging output to diagnose issues:

```shell
go run cmd/main.go fio --debug
```
