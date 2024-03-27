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

## Results

Host:

* Hardware: Mac mini (Apple M2 Pro, 8 performance and 4 efficiency cores, 32 GB RAM, `Mac14,12`)
* OS: macOS Sonoma 14.4.1

Guest:

* Hardware: [Virtualization.Framework](https://developer.apple.com/documentation/virtualization)
* OS: macOS Sonoma 14.4.1

```
Name                    	Executor	Bandwidth	I/O operations
Random writing of 1MB   	local   	2.6 GB/s 	649.35 kIOPS  
Random writing of 1MB   	Tart    	2.5 GB/s 	620.22 kIOPS  
Random writing of 10MB  	local   	2.6 GB/s 	651.74 kIOPS  
Random writing of 10MB  	Tart    	2.5 GB/s 	615.52 kIOPS  
Random writing of 100MB 	local   	1.9 GB/s 	481.51 kIOPS  
Random writing of 100MB 	Tart    	2.0 GB/s 	493.31 kIOPS  
Random writing of 1000MB	local   	1.7 GB/s 	414.89 kIOPS  
Random writing of 1000MB	Tart    	1.1 GB/s 	287.4 kIOPS  
```
