static char move_as_root_path_[64];

static const char *move_as_root_path() {
    if (move_as_root_path_[0] == '\0') {
        [[[NSBundle mainBundle] pathForResource:@"move_as_root" ofType:nil] getCString:move_as_root_path_
            maxLength:sizeof(move_as_root_path_)
            encoding:NSUTF8StringEncoding];
    }
    return move_as_root_path_;
}

void exec_move_as_root(const char *from, const char *to, const char *rem) {
    pid_t pid = fork();
    const char *path = move_as_root_path();
    if (pid == 0) {
        execl(path, path, from, to, rem, NULL);
        _exit(0);
    } else if (pid != -1) {
        int stat_loc;
        waitpid(pid, &stat_loc, 0);
    }
}
