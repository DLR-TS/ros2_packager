
.PHONY: build
build:
	colcon build --parallel-workers $$(nproc)

.PHONY: package
package:
	bash ros2_debian_packager.sh
