package main

import (
	"context"
	"github.com/cirruslabs/tart/benchmark/internal/command"
	"log"
	"os"
	"os/signal"
)

func main() {
	// Set up a signal-interruptible context
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt)

	// Run the root command
	if err := command.NewCommand().ExecuteContext(ctx); err != nil {
		cancel()

		log.Fatal(err)
	}

	cancel()
}
