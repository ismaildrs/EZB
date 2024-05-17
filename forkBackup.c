#include <stdio.h>
#include <stdlib.h>
#include <dirent.h>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <string.h>
#include <limits.h>

// Function to backup a file
void backup_file(char* file_name) {
    // Command to execute backup.sh with arguments
    char* args[] = {"sudo", "backup.sh", "-m", "-s", file_name, "-n", file_name, NULL};
    execvp(args[0], args);
    perror("Exec failed");
    exit(EXIT_FAILURE);
}

int main(int argc, char* argv[]) {
    // Check if directory path is provided
    if (argc != 2) {
        printf("Usage: %s <directory>\n", argv[0]);
        return 1;
    }

    // Open the directory
    DIR* dir = opendir(argv[1]);
    if (dir == NULL) {
        perror("Error opening directory");
        return 1;
    }

    // Read directory entries
    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL) {
        // Skip current and parent directory entries
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;
        }

        // Construct full path to the entry
        char entry_path[PATH_MAX];
        snprintf(entry_path, PATH_MAX, "%s/%s", argv[1], entry->d_name);

        // Get information about the entry
        struct stat entry_stat;
        if (stat(entry_path, &entry_stat) == -1) {
            perror("Error getting file status");
            closedir(dir);
            return 1;
        }

        // Check if it's a regular file
        if (S_ISREG(entry_stat.st_mode)) {
            // Fork child process to backup the file
            pid_t pid = fork();
            if (pid < 0) {
                // Fork error
                perror("Fork failed");
                closedir(dir);
                return 1;
            } else if (pid == 0) {
                // Child process
                backup_file(entry_path);
            }
        }
    }

    // Close the directory
    closedir(dir);

    // Wait for all child processes to finish
    int status;
    pid_t wpid;
    while ((wpid = wait(&status)) > 0);

    printf("All backup tasks completed.\n");

    return 0;
}
