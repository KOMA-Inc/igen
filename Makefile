.PHONY: build

build:
	swift build --scratch-path ./Build
	cp Build/debug/igen .

clean:
	rm -rf figma-export
	rm -rf Build

