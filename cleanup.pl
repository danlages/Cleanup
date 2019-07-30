#!/usr/bin/perl
#Student Name: Daniel Lages

use strict; 
use warnings; 
use File::Find;
use File::Copy;
use File::Path;
use File::Basename;

sub concatFileToKeep { #SubRoutine used in order to determine files not to delete as spcified in the command line 
    my ($dir, $initalFileArguments) = @_;
    my @fileArguments;
    foreach my $candidate (@$initalFileArguments) {
        push(@fileArguments, "$dir$candidate"); 
    }
    return @fileArguments;
}

sub get_all_file_Paths { #Get all File Paths of files in specified directory
    my ($dir) = @_;
    my @files;
    find(sub {push @files, $File::Find::name}, $dir); #push adds file name to array 
    return @files;
}

sub determineLinkedLines { #Look through files  
    my (@filteredFilesWithLink) = @_;
    my @linkedLines;
    foreach my $filesWithLink (@filteredFilesWithLink) {
    	if (-f $filesWithLink) {
        	open my $content, $filesWithLink or die "Could Not open file with link: $!"; 
        	while (my $line = <$content>) { #Determine lines that spcify a link using regular expression
            	if ($line =~ /href\s*=\s*"(.+?)"/ || $line =~ /src\s*=\s*"(.+?)"/ ) { 
                 	push(@linkedLines, $line);    
            	}
        	}
        close $content; 
    	}
    }
   return @linkedLines;
}

sub getPaths { #Seperate lines with links to create directory paths of linked file
    my (@linkedLines) = @_;
    my $path;
    my @linkedPaths;
    foreach my $linkedLine (@linkedLines) {
        ($path) = $linkedLine =~ /"([^"]*)"/;
        push(@linkedPaths, $path);
    }
    return @linkedPaths;
}

sub determinePaths{ #Using the grep comparsion method compare all files array with the files that have links - Determining what to delete
    my ($dir, $files, $pathsToMove) = @_;
    my @filesToKeep;
    foreach my $path (@$pathsToMove) {
        if (!grep(m/\$file$/, @$files)) { #Grep used in order to compare arrays    
            push(@filesToKeep, "$dir$path"); 
        }  
    }
    return @filesToKeep;
}

sub getFilesToMove { #Using determined file paths, determine the full path of files to delete
    my ($files, $filesToKeep, $fileArguments) = @_;
    my @filesToMove;
    foreach my $path (@$files) {
        if (-f $path) {
            if (!grep(/$path$/, @$filesToKeep) && !grep(/$path$/, @$fileArguments)) { #Gather paths using a combination of specified directory and determined path      
                push(@filesToMove, "$path");
            }
        }  
    }
    return @filesToMove;
}

sub moveFiles { #Subroutine for moving files whilst retaining directory structure
    my ($binDirectory, $filesToMove) = @_;
    my $fileName; 
    my $dirStruct;
    foreach my $path (@$filesToMove) {  
        $fileName = basename($path);
        $dirStruct = dirname($path);
        if ($dirStruct){
            my $structure = eval {mkpath("$binDirectory$dirStruct/")}; 
        }
        copy("$path", "$binDirectory$dirStruct") or die "Copy Failed: $!";
    }
}

sub deleteFiles { #Unlink function used to remove file from current directory
    my ($dir, $filesToMove) = @_;
    foreach my $path (@$filesToMove) {  
        unlink $path;
    }
}

my $numberOfArguments = $#ARGV + 1; #------------User input here
if ($numberOfArguments < 1) {
    print "\nIncorrect Number of Arguments - Aborting\n"; #Error message for aborting if incorrect arguments are given
    exit;
}

my @initalFileArguments; #Array used to handle arguments spcifying desired files to keep
my $fileC; #Placeholder for chosen file
if ($numberOfArguments > 1) {
    foreach my $filesChosen (2 .. $#ARGV)
    {
        $fileC = $filesChosen;
        push(@initalFileArguments, "$ARGV[$filesChosen]");
    }
}

my $dir = $ARGV[0]; #------------Sub Routines - Performaing operations
my $binDirectory = $ARGV[1]; #Handle bin directory argument, specified as second command line argument
mkpath("$binDirectory");
my $usedFilesDir = $ARGV[2]; 

my @fileArguments = concatFileToKeep($dir, \@initalFileArguments);
my @files = get_all_file_Paths($dir);
my @linkedLines = determineLinkedLines(@files);
my @linkedPaths = getPaths(@linkedLines);
my @filesToKeep = determinePaths($dir, \@files, \@linkedPaths);
my @filesToMove = getFilesToMove(\@files, \@filesToKeep, \@fileArguments);
moveFiles($binDirectory, \@filesToMove);
deleteFiles($dir, \@filesToMove);

my @analysedFiles; #Array to store all deleted files ready for analysis
find(sub {push @analysedFiles, $File::Find::name}, $binDirectory); #push adds file name to array 

my %fileSizeHash; #Hash to contain extention and corrisponding file sizes
my %fileCountHash; #Hash to contain extention and corrisponding number of files 
my $ext; #Hash extention placeholder
my $size; #Placeholder for file sizes 
my $count; #Placeholder for number of files 
my $overallFileCount = 0;
my $overallFileSize = 0;

foreach my $file (@analysedFiles) { #Hash implementation to contain extention and corrisponding file sizes
    if (-f $file){
        $size = -s $file;
        $overallFileSize = $overallFileSize + $size;
        $overallFileCount = $overallFileCount + 1;
        ($ext) = $file =~ /(\.[^.]+)$/; #Gather only file extention from file name handle using regular expression
        #Get file sizes here
        if (exists($fileSizeHash{"$ext"})) { #If file extention key added simply add to value of byte size
            my $value = $fileSizeHash{"$ext"};
            $value = $value + $size;
            $fileSizeHash{"$ext"} = $value;
        }
        else {
            if (!exists($fileSizeHash{"$ext"})) { #If file extention not present create new hash
            $fileSizeHash{"$ext"} = $size;
            }
        }
    }
}

foreach my $file (@analysedFiles) {
    if (-f $file){
        ($ext) = $file =~ /(\.[^.]+)$/; #Gather only file extention from file name handle using regular expression
        $count = 1;
        if (exists($fileCountHash{"$ext"})) { #If file extention key added simply add to value of file count
            my $value = $fileCountHash{"$ext"}; 
            $count = $count + 1;
            $fileCountHash{"$ext"} = $count;
        }
        else {
            if (!exists($fileCountHash{"$ext"})) {
            $fileCountHash{"$ext"} = $count;
            }
        }
    }
}

print "Cleanup Statisitcs for $dir:\n"; #Print filtered File Statisitcs
foreach my $item (keys %fileSizeHash) {
    print "$item Files: $fileCountHash{$item} file(s) $fileSizeHash{$item} bytes\n";
}
print "Total: $overallFileCount File(s) $overallFileSize bytes\n";