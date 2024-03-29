use inc::Module::Install;
use English qw(-no_match_vars);

name 'FusionInventory-Agent-Task-Deploy';
include 'Module::AutoInstall';
abstract 'Software deployment support';
license 'gpl';
version_from 'lib/FusionInventory/Agent/Task/Deploy.pm';
perl_version '5.008';

eval {
    # check for fusioninventory-agent setup
    require File::Which;
    my $agent = File::Which::which('fusioninventory-agent');
    die "fusioninventory-agent not found in PATH\n" unless $agent;

    my $command = 'fusioninventory-agent --setup 2>/dev/null';
    open (my $handle, '-|', $command) or die "can't run $command: $ERRNO";
    while (my $line = <$handle>) {
        chomp $line;
        next unless $line =~ /(\S+): (\S+)/;
        $MY::setup{uc($1)} = $2;
    }
    close $handle;

    push @INC, $MY::setup{LIBDIR};

    die "agent too old (minimal version 2.2.1 required)\n" if $CHILD_ERROR;
};
warn "unable to check fusioninventory-agent setup: $EVAL_ERROR" if $EVAL_ERROR;

# mandatory dependencies
requires 'Archive::Extract'       => undef;
requires 'Digest::SHA'            => undef;
requires 'File::Copy::Recursive'  => undef;
requires 'JSON'                   => undef;
requires 'URI::Escape'            => undef;
requires 'UNIVERSAL::require'     => undef;

recommends 'POE::Component::Client::Ping' => undef;

test_requires 'Test::HTTP::Server::Simple' => undef;
test_requires 'Test::Compile' => undef;
test_requires 'POE::Component::Client::Ping' => undef;

WriteAll;

# substitute prefix everywhere
$MY::variables{DATADIR} =~ s/\$\(PREFIX\)/$MY::variables{PREFIX}/;

print <<EOF;

Installation summary
--------------------
prefix: $MY::variables{PREFIX}
constant data installation directory: $MY::variables{DATADIR}

EOF

package MY;

our %setup;
our %variables;

# force a perl-independant prefix for everything but perl modules
sub constants {
    my ($self) = @_;

    # for some reason, initialising variables from the global scope doesn't work
    %variables = (
        PREFIX               => '/usr/local',
        INSTALLLIB           => '$(DATADIR)/lib',
        INSTALLSITELIB       => '$(DATADIR)/lib',
        INSTALLVENDORLIB     => '$(DATADIR)/lib',
        INSTALLMAN3DIR       => '$(PREFIX)/share/man/man3',
        INSTALLSITEMAN3DIR   => '$(PREFIX)/share/man/man3',
        INSTALLVENDORMAN3DIR => '$(PREFIX)/share/man/man3',
        DATADIR              => '$(PREFIX)/share/fusioninventory',
        FULLPERLRUN          => '$(FULLPERL) -I$(DATADIR)/lib'
    );

    # allow variables detected from agent setup to override defaults
    foreach my $name (keys %variables) {
        $variables{$name} = $setup{$name} if $setup{$name};
    }

    # allow variables defined on command line to override defaults
    foreach my $name (keys %variables) {
        $variables{$name} = $self->{ARGS}->{$name} if $self->{ARGS}->{$name};
    }

    # get all standard MM variables definitions, and override them if needed
    my @code = split(/\n/, $self->SUPER::constants(@_));
    foreach my $line (@code) {
        # Skip comments
        next if $line =~ /^\s*#/;
        # Skip everything which isn't a var assignment.
        next unless $line =~ /^([A-Z0-9_]+) =/;
        my $name = $1;
        # skip variables we're not interested
        next unless $variables{$name};

        $line = "$name = $variables{$name}";
    }

    # add out own variables
    foreach my $name (qw/DATADIR/) {
        push @code, "$name = $variables{$name}";
    }

    return join("\n", @code);
}
