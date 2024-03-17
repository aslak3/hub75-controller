package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/sergeymakinen/go-bmp"
)

func output_bmp_as_raw(filename string) {
	f, _ := os.Open(filename)
	img, _ := bmp.Decode(f)

	bounds := img.Bounds()

	for y := 0; y < bounds.Dy(); y++ {
		for x := 0; x < bounds.Dx(); x++ {
			pixel := img.At(x, y)
			r, g, b, _ := pixel.RGBA()
			fmt.Printf("%02x%02x%02x00\n", r/256, g/256, b/256)
		}
	}
}

func main() {
	inputFilenamePtr := flag.String("input-filename", "", "A 64 x 32 bmp file")

	flag.Parse()

	if *inputFilenamePtr == "" {
		fmt.Fprintf(os.Stderr, "--input-filename not specified\n")
		os.Exit(1)
	}

	output_bmp_as_raw(*inputFilenamePtr)
}
