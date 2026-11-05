APP      := VilisWhisp
BUILD    := build
BUNDLE   := $(BUILD)/$(APP).app

.PHONY: build app run clean icon

build:
	swift build -c release

app: build
	bash scripts/bundle.sh

run: app
	open "$(BUNDLE)"

icon:
	bash scripts/make_icon.sh

clean:
	rm -rf .build "$(BUILD)"
