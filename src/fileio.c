#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdint.h>
#include "videre.h"

// Validate filename to prevent path traversal attacks
int editorValidateFilename(const char *filename) {
    if (!filename || strlen(filename) == 0) return 0;
    
    // Check for path traversal patterns
    if (strstr(filename, "..") != NULL) return 0;
    if (strstr(filename, "/") == filename && strlen(filename) > 1) {
        // Absolute path - check if it's within reasonable bounds
        if (strlen(filename) > 4096) return 0; // Reasonable path length limit
    }
    
    // Check for dangerous characters
    const char *dangerous = "<>\"|&;$`'()[]{}*?~";
    for (const char *p = filename; *p; p++) {
        if (strchr(dangerous, *p)) return 0;
    }
    
    // Check if file exists and is regular file
    struct stat st;
    if (stat(filename, &st) == 0) {
        if (!S_ISREG(st.st_mode)) return 0;
        
        // Reasonable file size limit (100MB)
        if (st.st_size > 100 * 1024 * 1024) return 0;
    }
    
    return 1;
}

void editorUpdateGitStatus() {
    E.git_status[0] = '\0';
    if (!E.filename) return;

    FILE *fp = popen("git status --porcelain -b 2>/dev/null", "r");
    if (!fp) return;

    char line[1024];
    if (fgets(line, sizeof(line), fp)) {
        // First line is branch info: "## branch_name...remote_branch [ahead X, behind Y]"
        if (strncmp(line, "## ", 3) == 0) {
            char *branch = line + 3;
            char *end = strstr(branch, "...");
            if (!end) end = strpbrk(branch, " \t\n\r");
            if (end) *end = '\0';
            
            int has_changes = 0;
            if (fgets(line, sizeof(line), fp)) {
                has_changes = 1;
            }
            
            // Use a temporary buffer to avoid truncation warnings and ensure safety
            char status_buf[64];
            snprintf(status_buf, sizeof(status_buf), "%s%s", branch, has_changes ? "*" : "");
            strncpy(E.git_status, status_buf, sizeof(E.git_status) - 1);
            E.git_status[sizeof(E.git_status) - 1] = '\0';
        }
    }
    pclose(fp);
}

void editorOpen(char *filename) {
    // Validate filename before opening
    if (!editorValidateFilename(filename)) {
        editorSetStatusMessage("Invalid filename or path");
        return;
    }
    
    FILE *fp = fopen(filename, "r");
    if (!fp) {
        editorSetStatusMessage("Can't open file: %s", strerror(errno));
        return;
    }

    char *line = NULL;
    size_t linecap = 0;
    ssize_t linelen;
    while ((linelen = getline(&line, &linecap, fp)) != -1) {
        while (linelen > 0 && (line[linelen - 1] == '\n' ||
                               line[linelen - 1] == '\r'))
            linelen--;
        editorInsertRow(E.numrows, line, linelen);
    }
    free(line);
    fclose(fp);
    
    int total_chars = 0;
    for (int i = 0; i < E.numrows; i++) total_chars += E.row[i].size;

    E.dirty = 0;
    editorSelectSyntaxHighlight();
    editorUpdateGitStatus();
}

char *editorRowsToString(int *buflen) {
    size_t totlen = 0;
    int j;
    for (j = 0; j < E.numrows; j++) {
        // Prevent integer overflow when calculating total length
        if (totlen > SIZE_MAX - E.row[j].size - 1) {
            die("Buffer size overflow in editorRowsToString");
        }
        totlen += E.row[j].size + 1;
    }
    *buflen = (int)totlen; // Note: possible truncation if totlen > INT_MAX, but buflen is often used with write()

    char *buf = malloc(totlen);
    if (!buf) die("malloc");
    char *p = buf;
    for (j = 0; j < E.numrows; j++) {
        memcpy(p, E.row[j].chars, E.row[j].size);
        p += E.row[j].size;
        *p = '\n';
        p++;
    }

    return buf;
}

void editorSave() {
    if (E.filename == NULL) {
        E.filename = editorPrompt("Save as: %s", NULL);
        if (E.filename == NULL) {
            editorSetStatusMessage("Save aborted");
            return;
        }
        editorSelectSyntaxHighlight();
    }

    // Validate filename before saving
    if (!editorValidateFilename(E.filename)) {
        editorSetStatusMessage("Invalid filename for saving");
        return;
    }

    int len;
    char *buf = editorRowsToString(&len);

    int fd = open(E.filename, O_RDWR | O_CREAT, 0644);
    if (fd != -1) {
        if (ftruncate(fd, len) != -1) {
            if (write(fd, buf, len) == len) {
                close(fd);
                free(buf);
                E.dirty = 0;
                editorUpdateGitStatus();
                editorSetStatusMessage("\"%s\" %dL, %dC written", E.filename, E.numrows, len);
                return;
            }
        }
        close(fd);
    }

    free(buf);
    editorSetStatusMessage("Can't save! I/O error: %s", strerror(errno));
}
