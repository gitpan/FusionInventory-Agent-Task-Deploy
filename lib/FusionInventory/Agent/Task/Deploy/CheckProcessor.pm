package FusionInventory::Agent::Task::Deploy::CheckProcessor;

use strict;
use warnings;

use English qw(-no_match_vars);
use Digest::SHA;

use FusionInventory::Agent::Task::Deploy::DiskFree;

sub process {
    my ($self, %params) = @_;

    # the code to return in case of failure of the check,
    # the default is 'ko'
    my $failureCode = $params{check}->{return} || "ko";

    if ($params{check}->{type} eq 'winkeyExists') {
        return unless $OSNAME eq 'MSWin32';
        require FusionInventory::Agent::Tools::Win32;

        my $path = $params{check}->{path};
        $path =~ s{\\}{/}g;

        my $r = FusionInventory::Agent::Tools::Win32::getRegistryKey(path => $path);

        return defined $r ? 'ok' : $failureCode;
    }

    if ($params{check}->{type} eq 'winkeyEquals') {
        return unless $OSNAME eq 'MSWin32';
        require FusionInventory::Agent::Tools::Win32;

        my $path = $params{check}->{path};
        $path =~ s{\\}{/}g;

        my $r = FusionInventory::Agent::Tools::Win32::getRegistryValue(path => $path);

        return defined $r && $params{check}->{value} eq $r ? 'ok' : $failureCode;
    }
    
    if ($params{check}->{type} eq 'winkeyMissing') {
        return unless $OSNAME eq 'MSWin32';
        require FusionInventory::Agent::Tools::Win32;

        my $path = $params{check}->{path};
        $path =~ s{\\}{/}g;

        my $r = FusionInventory::Agent::Tools::Win32::getRegistryKey(path => $path);

        return defined $r ? $failureCode : 'ok';
    } 

    if ($params{check}->{type} eq 'fileExists') {
        return -f $params{check}->{path} ? 'ok' : $failureCode;
    }

    if ($params{check}->{type} eq 'fileSizeEquals') {
        my @s = stat($params{check}->{path});
        return @s ? 'ok' : $failureCode;
    }

    if ($params{check}->{type} eq 'fileSizeGreater') {
        my @s = stat($params{check}->{path});
        return $failureCode unless @s;

        return $params{check}->{value} < $s[7] ? 'ok' : $failureCode;
    }

    if ($params{check}->{type} eq 'fileSizeLower') {
        my @s = stat($params{check}->{path});
        return $failureCode unless @s;
        return $params{check}->{value} > $s[7] ? 'ok' : $failureCode;
    }
    
    if ($params{check}->{type} eq 'fileMissing') {
        return -f $params{check}->{path} ? $failureCode : 'ok';
    }
    
    if ($params{check}->{type} eq 'freespaceGreater') {
        my $freespace = getFreeSpace(logger => $params{logger}, path => $params{check}->{path});
        return $freespace>$params{check}->{value}? "ok" : $failureCode;
    }

    if ($params{check}->{type} eq 'fileSHA512') {
        my $sha = Digest::SHA->new('512');

        my $sha512 = "";
        eval {
            $sha->addfile($params{check}->{path}, 'b');
            $sha512 = $sha->hexdigest;
        };


        return $sha512 eq $params{check}->{value} ? "ok" : $failureCode;
    }

    if ($params{check}->{type} eq 'directoryExists') {
        return -d $params{check}->{path} ? 'ok' : $failureCode;
    }

    if ($params{check}->{type} eq 'directoryMissing') {
        return -d $params{check}->{path} ? $failureCode : 'ok';
    }


    print "Unknown check: `".$params{check}->{type}."'\n";

    return "ok";
}

1;
