/*

move_as_root ... Move a file as root.
Copyright (C) 2009  KennyTM~ <kennytm@gmail.com>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

*/

#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>

// Usage: move_as_root temp_file expected_place file_to_remove
// Usage: move_as_root file_name
int main(int argc, const char* argv[]) {
	setuid(geteuid());
	if (argc == 4) {
		if (strcmp(argv[1], argv[2]) != 0)
			rename(argv[1], argv[2]);
		unlink(argv[3]);
	} else if (argc == 2) {
		int fd = open(argv[1], O_RDONLY);
		char buf[1024];
		size_t actual_size;
		while ((actual_size = read(fd, buf, 1024)) > 0) {
			fwrite(buf, 1, actual_size, stdout);
		}
		close(fd);
	}
	return 0;
}
