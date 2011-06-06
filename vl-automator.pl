#!/usr/bin/perl

use strict;
use warnings;

use LWP::UserAgent;
use Getopt::Std;

# hashref to hold our options...
my $OPTS = {};

# get the options using Getopt::Std's exported 'getopts'
getopts('c:',$OPTS);

my $CONFIG = "$ENV{HOME}/.storm8-vl.conf";
   $CONFIG = $$OPTS{c} if ($$OPTS{c});

my $conf = read_config($CONFIG);
exit 1 unless ($conf);

foreach my $key (keys %$conf) {
    print "$key: $$conf{$key}\n";
}

exit 0;


sub read_config {
    my $conf_file = shift;

    my %options = ();
    if (open FILE,'<',$conf_file) {
        while (<FILE>) {
            my $line = $_;
            next if ($line =~ /^\s*$/);
            next if ($line =~ /^\s*#/);
            $line =~ s/^\s*//;
            $line =~ s/\s*$//;
            my ($opt,$val) = split(/\s*=\s*/,$line);
            $options{$opt} = $val;
        }
        close FILE;
    } else {
        print STDERR "unable to open $conf_file: $!\n";
        return undef;
    }
    return \%options;
}
