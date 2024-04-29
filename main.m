#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <spawn.h>
#include <unistd.h>
#include <sys/sysctl.h>
#include <stdbool.h>
#include <sys/types.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <sys/stat.h>


#define resFile "/var/mobile/Library/Preferences/com.apple.iokit.IOMobileGraphicsFamily.plist"
#define tmpResFile "/private/var/tmp/com.apple.iokit.IOMobileGraphicsFamily.plist"
#define resFileBackup "/var/mobile/Library/Preferences/com.apple.iokit.IOMobileGraphicsFamily.plist_system_info_backup"

static bool isRootless = false;
typedef CFPropertyListRef (*MGCopyAnswer)(CFStringRef);


CFPropertyListRef getDeviceInfo(MGCopyAnswer MGCopyAnswerFunc, NSString *info) {
    NSLog(@"[*] Getting %@", info);
    return MGCopyAnswerFunc((__bridge CFStringRef)info);
}

int run(const char *cmd, char * const *args) {
    int pid = 0;
    int retval = 0;
    char printbuf[0x1000] = {};
	
	// Set up environment with additional directories in PATH
    const char *env[] = {
        "PATH=/usr/local/sbin:/var/jb/usr/local/sbin:"
        "/usr/local/bin:/var/jb/usr/local/bin:"
        "/usr/sbin:/var/jb/usr/sbin:"
        "/usr/bin:/var/jb/usr/bin:"
        "/sbin:/var/jb/sbin:"
        "/bin:/var/jb/bin:"
        "/usr/bin/X11:/var/jb/usr/bin/X11:"
        "/usr/games:/var/jb/usr/games",
        "NO_PASSWORD_PROMPT=1",
        NULL
    };

    for (char * const *a = args; *a; a++) {
        size_t csize = strlen(printbuf);
        if (csize >= sizeof(printbuf)) break;
        snprintf(printbuf+csize,sizeof(printbuf)-csize, "%s ",*a);
    }

    // Set up environment
    char *const *envp = (char *const *)env;

    retval = posix_spawn(&pid, cmd, NULL, NULL, args, envp);

    {
        int pidret = 0;
        retval = waitpid(pid, &pidret, 0);
        return pidret;
    }
    return retval;
}

void printUsage() {
	printf("\n\n-------------------- Resolution Changer --------------------\n\n");
	printf("usage: iofbress (height) (width)\n\nex: iphone 6s resolution 1334x750, iphonePlus devices 1920x1080, iphone SE device 1136x640\n");
	printf("others option: \nrestore default resolution: -r\nApply new resolution by respring: -a\nShow current resolution: -s\nshow this help: -h\n");
	exit(0);
}

void restoreDefault() {
	if (access(resFile, F_OK) != 0) {
		printf("[/] Resolution is already on default\n");
		exit(0);
	}

	if (remove("/var/mobile/Library/Preferences/com.apple.iokit.IOMobileGraphicsFamily.plist") == 0) printf("DONE.\n"); 
	else printf("error restoring default resolution\n");
}

void applyResolution() {
    char* respringArgs[2];

    if (isRootless == false) {
        respringArgs[0] = "/usr/bin/ldrestart";
    } else {
        respringArgs[0] = "/var/jb/usr/bin/ldrestart";
    }
    respringArgs[1] = NULL; // Terminating the array with NULL

    run(respringArgs[0], respringArgs);
}

void showResulution() {
    UIScreen *mainScreen = [UIScreen mainScreen];
    CGRect screenBounds = [mainScreen bounds];
    
    CGFloat screenWidth = CGRectGetWidth(screenBounds);
    CGFloat screenHeight = CGRectGetHeight(screenBounds);
        
    NSLog(@"Screen resolution: %.0f x %.0f", screenHeight * 2, screenWidth * 2);
}

void setResolution(char *height, char *width) {
	
	if (access(resFileBackup, F_OK) != 0) {
		printf("[/] Creating resolution backup");
		void *gestaltLib = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY);
        
		if (gestaltLib != NULL) {
            NSLog(@"[*] libMobileGestalt.dylib Loaded successfully");
            MGCopyAnswer copyAnswer = (MGCopyAnswer)dlsym(gestaltLib, "MGCopyAnswer");
        
            if (copyAnswer != NULL) {

            	NSLog(@"[*] MGCopyAnswer Method Loaded Successfully");
				CFPropertyListRef heightValue = getDeviceInfo(copyAnswer, @"main-screen-height");
				CFPropertyListRef widthValue = getDeviceInfo(copyAnswer, @"main-screen-width");

				NSString *heightStr = (__bridge NSString*)heightValue;
				NSString *widthStr = (__bridge NSString*)widthValue;

    			// Convert CFTypeRef values to integers
   				NSInteger heightNumber = [heightStr intValue];
    			NSInteger widthNumber = [widthStr intValue];

				NSLog(@"height original: %ld, width original: %ld\n", heightNumber, widthNumber);
 				NSDictionary *resDict = @{@"canvas_height": [NSNumber numberWithInteger:heightNumber], @"canvas_width": [NSNumber numberWithInteger:widthNumber]};

    			if ([resDict writeToFile:[NSString stringWithUTF8String:resFileBackup] atomically:YES]) {
					printf("[*] created backup sucessfully");
				} else {
					printf("[-] failed to create backup");
					return;
				}
			}
		}
	}

    NSInteger heightNumber = [[NSString stringWithUTF8String:height] intValue];
    NSInteger widthNumber = [[NSString stringWithUTF8String:width] intValue];

    NSDictionary *resDict = @{@"canvas_height": [NSNumber numberWithInteger:heightNumber], @"canvas_width": [NSNumber numberWithInteger:widthNumber]};

    if ([resDict writeToFile:[NSString stringWithUTF8String:tmpResFile] atomically:YES]) {
		int result = symlink(tmpResFile, resFile);
    	if (result != 0) perror("Error creating symbolic link");

		printf("resolution set sucessfully");
	} else printf("failed to set resolution");
}

int main(int argc, char *argv[], char *envp[]) {
	@autoreleasepool {
		if (access("/var/jb", F_OK) == 0) isRootless = true;
		if (argc < 1 || argc > 3 || argv[1] == NULL) {
			printUsage();
		} else if (argv[1] != NULL) {
			if (strncmp(argv[1], "-h", 3) == 0) printUsage(); 
			else if (strncmp(argv[1], "-r", 3) == 0) restoreDefault();
			else if (strncmp(argv[1], "-a", 3) == 0) applyResolution();
			else if (strncmp(argv[1], "-s", 3) == 0) showResulution();
			else if (argv[2] != NULL) setResolution(argv[1], argv[2]);
			else printUsage();
		}

		return 0;
	}
}
