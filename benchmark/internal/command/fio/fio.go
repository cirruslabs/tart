package fio

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/cirruslabs/tart/benchmark/internal/executor"
	"github.com/cirruslabs/tart/benchmark/internal/executor/local"
	"github.com/cirruslabs/tart/benchmark/internal/executor/tart"
	"github.com/dustin/go-humanize"
	"github.com/gosuri/uitable"
	"github.com/spf13/cobra"
	"go.uber.org/zap"
)

var debug bool

func NewCommand() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "fio",
		Short: "run Flexible I/O tester (fio) benchmarks",
		RunE:  run,
	}

	cmd.Flags().BoolVar(&debug, "debug", false, "enable debug logging")

	return cmd
}

func run(cmd *cobra.Command, args []string) error {
	config := zap.NewProductionConfig()
	if debug {
		config.Level = zap.NewAtomicLevelAt(zap.DebugLevel)
	}
	logger, err := config.Build()
	if err != nil {
		return err
	}
	defer func() {
		_ = logger.Sync()
	}()

	executors, err := initializeExecutors(cmd.Context(), logger)
	if err != nil {
		return err
	}
	defer func() {
		errs := []error{err}

		for _, executor := range executors {
			if err := executor.Close(); err != nil {
				errs = append(errs, fmt.Errorf("failed to close executor %s: %w", executor.Name(), err))
			}
		}

		err = errors.Join(errs...)
	}()

	table := uitable.New()
	table.AddRow("Name", "Executor", "Bandwidth", "I/O operations")

	for _, benchmark := range benchmarks {
		for _, executor := range executors {
			logger.Sugar().Infof("running benchmark %q on %s executor", benchmark.Name, executor.Name())

			stdout, err := executor.Run(cmd.Context(), benchmark.Command)
			if err != nil {
				return err
			}

			var fioResult Result

			if err := json.Unmarshal(stdout, &fioResult); err != nil {
				return err
			}

			if len(fioResult.Jobs) != 1 {
				return fmt.Errorf("expected exactly 1 job from fio's JSON output, got %d",
					len(fioResult.Jobs))
			}

			job := fioResult.Jobs[0]

			writeBandwidth := humanize.Bytes(uint64(job.Write.BW)*humanize.KByte) + "/s"
			writeIOPS := humanize.SIWithDigits(job.Write.IOPS, 2, "IOPS")

			logger.Sugar().Infof("write bandwidth: %s, write IOPS: %s\n", writeBandwidth, writeIOPS)

			table.AddRow(benchmark.Name, executor.Name(), writeBandwidth, writeIOPS)
		}
	}

	fmt.Println(table.String())

	return nil
}

func initializeExecutors(ctx context.Context, logger *zap.Logger) ([]executor.Executor, error) {
	var result []executor.Executor

	logger.Info("initializing local executor")

	local, err := local.New(logger)
	if err != nil {
		return nil, err
	}
	result = append(result, local)

	logger.Info("local executor initialized")

	logger.Info("initializing Tart executor")

	tart, err := tart.New(ctx, logger)
	if err != nil {
		return nil, err
	}
	result = append(result, tart)

	logger.Info("Tart executor initialized")

	for _, executor := range result {
		logger.Sugar().Infof("installing Flexible I/O tester (fio) on %s executor", executor.Name())

		if _, err := executor.Run(ctx, "brew install fio"); err != nil {
			return nil, err
		}
	}

	return result, nil
}
