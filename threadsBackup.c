#include <stdio.h>
#include <stdlib.h>
#include <dirent.h>
#include <pthread.h>
#include <sys/stat.h>
#include <string.h>
#include <limits.h>
#include <unistd.h>

#define MAX_THREADS 10 // Maximum number of threads for parallel execution

// Function to backup a file
void *backup_file(void *file_name) {
    char* file_path = (char *)file_name;
    // Command to execute backup.sh with arguments
    char* args[] = {"sudo", "backup.sh", "-m", "-s", file_path, "-n", file_path, NULL};
    execvp(args[0], args);
    perror("Exec failed");
    pthread_exit(NULL);
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
    pthread_t threads[MAX_THREADS]; // Array to store thread IDs
    int thread_count = 0; // Counter for active threads

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
            // Create a thread to backup the file
            if (pthread_create(&threads[thread_count], NULL, backup_file, (void *)strdup(entry_path)) != 0) {
                perror("Thread creation failed");
                closedir(dir);
                return 1;
            }
            thread_count++;
        }
    }

    // Close the directory
    closedir(dir);

    // Wait for all threads to complete
    for (int i = 0; i < thread_count; i++) {
        pthread_join(threads[i], NULL);
    }

    printf("All backup tasks completed.\n");

    pthread_exit(NULL);
}
