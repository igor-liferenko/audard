#!/usr/bin/perl

# original from http://www.math.ubc.ca/~cass/graphics/manual/code/psinc
# mod sdaau 2012

# This reads in ps files, printing out all lines except
# ^( ... ) run
# where it performs an inclusion --- recursively.
# The current directory is updated.
# I think I got the skeleton from p. 192 of "Programming Perl"

use File::Basename;

include("", STDIN, 0, "stdin");

# insert a file into output

sub include {
	local($curdir, $input, $depth, $cf) = @_;
	$i = $depth; 
	while ($i > 0) {
		print STDERR "  ";
		$i--;
	}
	print STDERR "Opening $cf\n";
	$fh++;
	while ($_ = <$input>) {
#		if (/^\((.*)\)[ ]*run/) {
		if (/^(\s*)\((.*)\)[ ]*run/) {
#			($name, $dir, $suffix) = fileparse($1, '');
#			print STDERR $1, $2; # debug
			($name, $dir, $suffix) = fileparse($2, '');
			if ($dir eq './') {
				$dir = "";
			}
			$file = "$curdir$dir$name$suffix";
			print STDERR "% file to open = {$file}\n";
			if (open($fh, $file)) {
				print "\n";
				print "% - Inserting $name ----------------------\n\n";
				include($curdir.$dir, $fh, $depth+1, $file);
			} else {
				print("Current directory $curdir.$dir\n");
				print STDERR "Unable to open $file\n";
				exit 1;
				
			}  
		} else {
			print $_;
		}
	}
	if ($input ne STDIN) {
		$i = $depth; 
		while ($i > 0) {
			print STDERR "  ";
			$i--;
		}
		print "\n";
		print "% - closing $name ------------------------\n";
		print STDERR "Closing $cf\n";
		close($input);
	}
}

