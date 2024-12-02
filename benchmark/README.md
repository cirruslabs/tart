# Benchmark

Tart comes with a Golang-based benchmarking utility that allows one to easily compare host and guest performance.

Currently, only Flexible I/O tester workloads are supported. To run them, [install Golang](https://go.dev/) and run the following command from this (`benchmark/`) directory:

```shell
go run cmd/main.go fio --image ghcr.io/cirruslabs/macos-sonoma-base:latest
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

Host:

* Hardware: MacBook Pro (Apple M1 Pro, 8 performance and 2 efficiency cores, 32 GB RAM, `MacBookPro18,3`)
* OS: macOS Sequoia 15.1.1

Guest:

* Hardware: [Virtualization.Framework](https://developer.apple.com/documentation/virtualization)
* OS: macOS Sonoma 14.6

```
Name                                    	Executor                                          	B/W (read)	B/W (write)	I/O (read) 	I/O (write) 	Latency (read)          	Latency (write)         	Latency (sync)      
Single 4KiB random write process        	local                                             	0 B/s     	19 MB/s    	0 IOPS     	4.81 kIOPS  	0s ± 0s                 	203.418µs ± 155.865µs   	0s ± 0s             
Single 4KiB random write process        	Tart                                              	0 B/s     	18 MB/s    	0 IOPS     	4.54 kIOPS  	0s ± 0s                 	213.655µs ± 188.822µs   	0s ± 0s             
Single 4KiB random write process        	Tart (--root-disk-opts="sync=none")               	0 B/s     	19 MB/s    	0 IOPS     	4.68 kIOPS  	0s ± 0s                 	208.413µs ± 183.45µs    	0s ± 0s             
Single 4KiB random write process        	Tart (--root-disk-opts="caching=cached")          	0 B/s     	24 MB/s    	0 IOPS     	6.11 kIOPS  	0s ± 0s                 	158.07µs ± 2.294654ms   	0s ± 0s             
Single 4KiB random write process        	Tart (--root-disk-opts="sync=none,caching=cached")	0 B/s     	22 MB/s    	0 IOPS     	5.49 kIOPS  	0s ± 0s                 	173.414µs ± 310.213µs   	0s ± 0s             
16 parallel 64KiB random write processes	local                                             	0 B/s     	18 GB/s    	0 IOPS     	273.76 kIOPS	0s ± 0s                 	323.423µs ± 604.999µs   	0s ± 0s             
16 parallel 64KiB random write processes	Tart                                              	0 B/s     	16 GB/s    	0 IOPS     	273.48 kIOPS	0s ± 0s                 	335.086µs ± 7.591748ms  	0s ± 0s             
16 parallel 64KiB random write processes	Tart (--root-disk-opts="sync=none")               	0 B/s     	18 GB/s    	0 IOPS     	281.49 kIOPS	0s ± 0s                 	326.655µs ± 7.485473ms  	0s ± 0s             
16 parallel 64KiB random write processes	Tart (--root-disk-opts="caching=cached")          	0 B/s     	17 GB/s    	0 IOPS     	266.79 kIOPS	0s ± 0s                 	340µs ± 7.868384ms      	0s ± 0s             
16 parallel 64KiB random write processes	Tart (--root-disk-opts="sync=none,caching=cached")	0 B/s     	16 GB/s    	0 IOPS     	251.02 kIOPS	0s ± 0s                 	355.077µs ± 8.354218ms  	0s ± 0s             
Single 1MiB random write process        	local                                             	0 B/s     	1.3 GB/s   	0 IOPS     	1.31 kIOPS  	0s ± 0s                 	751.716µs ± 370.731µs   	0s ± 0s             
Single 1MiB random write process        	Tart                                              	0 B/s     	1.1 GB/s   	0 IOPS     	1.1 kIOPS   	0s ± 0s                 	885.833µs ± 3.572539ms  	0s ± 0s             
Single 1MiB random write process        	Tart (--root-disk-opts="sync=none")               	0 B/s     	1.1 GB/s   	0 IOPS     	1.08 kIOPS  	0s ± 0s                 	898.427µs ± 3.464261ms  	0s ± 0s             
Single 1MiB random write process        	Tart (--root-disk-opts="caching=cached")          	0 B/s     	1000 MB/s  	0 IOPS     	976.47 IOPS 	0s ± 0s                 	972.491µs ± 6.87654ms   	0s ± 0s             
Single 1MiB random write process        	Tart (--root-disk-opts="sync=none,caching=cached")	0 B/s     	1.1 GB/s   	0 IOPS     	1.03 kIOPS  	0s ± 0s                 	925.545µs ± 4.261693ms  	0s ± 0s             
Random reads/writes (4k)                	local                                             	62 MB/s   	62 MB/s    	15.37 kIOPS	15.37 kIOPS 	2.059453ms ± 1.431822ms 	2.098761ms ± 1.445082ms 	0s ± 0s             
Random reads/writes (4k)                	Tart                                              	38 MB/s   	38 MB/s    	9.6 kIOPS  	9.61 kIOPS  	3.30369ms ± 1.500464ms  	3.350589ms ± 1.512986ms 	0s ± 0s             
Random reads/writes (4k)                	Tart (--root-disk-opts="sync=none")               	39 MB/s   	39 MB/s    	9.82 kIOPS 	9.83 kIOPS  	3.228106ms ± 1.367512ms 	3.27626ms ± 1.385964ms  	0s ± 0s             
Random reads/writes (4k)                	Tart (--root-disk-opts="caching=cached")          	35 MB/s   	35 MB/s    	8.74 kIOPS 	8.76 kIOPS  	3.640772ms ± 15.472355ms	3.661779ms ± 15.264288ms	0s ± 0s             
Random reads/writes (4k)                	Tart (--root-disk-opts="sync=none,caching=cached")	24 MB/s   	24 MB/s    	5.98 kIOPS 	5.99 kIOPS  	5.31188ms ± 4.55205ms   	5.375047ms ± 5.113847ms 	0s ± 0s             
Random reads/writes (64k)               	local                                             	435 MB/s  	436 MB/s   	6.79 kIOPS 	6.8 kIOPS   	4.955892ms ± 2.066685ms 	4.440414ms ± 1.860036ms 	0s ± 0s             
Random reads/writes (64k)               	Tart                                              	352 MB/s  	353 MB/s   	5.5 kIOPS  	5.51 kIOPS  	5.946067ms ± 2.041124ms 	5.658948ms ± 1.928372ms 	0s ± 0s             
Random reads/writes (64k)               	Tart (--root-disk-opts="sync=none")               	331 MB/s  	332 MB/s   	5.16 kIOPS 	5.17 kIOPS  	6.330765ms ± 1.726782ms 	6.033862ms ± 1.671028ms 	0s ± 0s             
Random reads/writes (64k)               	Tart (--root-disk-opts="caching=cached")          	428 MB/s  	428 MB/s   	6.68 kIOPS 	6.69 kIOPS  	4.661666ms ± 18.342779ms	4.904961ms ± 18.396772ms	0s ± 0s             
Random reads/writes (64k)               	Tart (--root-disk-opts="sync=none,caching=cached")	297 MB/s  	298 MB/s   	4.64 kIOPS 	4.65 kIOPS  	6.591009ms ± 2.827053ms 	7.166883ms ± 3.001036ms 	0s ± 0s             
sync test                               	local                                             	0 B/s     	48 MB/s    	0 IOPS     	21.15 kIOPS 	0s ± 0s                 	23.471µs ± 81.868µs     	23.374µs ± 6.255µs  
sync test                               	Tart                                              	0 B/s     	24 MB/s    	0 IOPS     	10.72 kIOPS 	0s ± 0s                 	24.983µs ± 61.761µs     	67.575µs ± 76.196µs 
sync test                               	Tart (--root-disk-opts="sync=none")               	0 B/s     	21 MB/s    	0 IOPS     	9.5 kIOPS   	0s ± 0s                 	26.973µs ± 63.935µs     	77.388µs ± 47.103µs 
sync test                               	Tart (--root-disk-opts="caching=cached")          	0 B/s     	30 MB/s    	0 IOPS     	13.19 kIOPS 	0s ± 0s                 	11.923µs ± 25.225µs     	62.894µs ± 208.933µs
sync test                               	Tart (--root-disk-opts="sync=none,caching=cached")	0 B/s     	38 MB/s    	0 IOPS     	17.02 kIOPS 	0s ± 0s                 	10.124µs ± 21.868µs     	47.803µs ± 33.706µs
```
