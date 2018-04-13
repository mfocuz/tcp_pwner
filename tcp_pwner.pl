#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use IO::Socket::INET;

my $PROTO_DESC_FILE = $ARGV[0];
my ($PROTO,$HOST,$PORT) = split(/:/,$ARGV[1]);
#my @CONTROL = split(/\//,$ARGV[2]);

#my $CONTROL_FIELD_RECV = '^' . $CONTROL[0] . '$' || '^recv:$';
#my $CONTROL_FIELD_SEND = '^' . $CONTROL[1] . '$' || '^send:$';
#my $CONTROL_FIELD_END = '^' . $CONTROL[2] . '$' || '^end:$';
my $CONTROL_FIELD_RECV = '^recv:$';
my $CONTROL_FIELD_SEND = '^send:$';
my $CONTROL_FIELD_END = '^end:$';
my $BUFFER;
my $CLIENT;
$| = 1;

my $tcpFlow = parse_description($PROTO_DESC_FILE);
my $instrinctions = $tcpFlow->{instructions};
my $data = $tcpFlow->{data};

pinit();
my $ip = 0;
foreach my $instruction (@$instrinctions) {
    my $func;
    if($instruction =~ /$CONTROL_FIELD_RECV/) {
        $func = \&precv;
    } elsif ($instruction =~ $CONTROL_FIELD_SEND) {
        $func = \&psend;
    } elsif ($instruction =~ $CONTROL_FIELD_END) {
        $func = \&pend;
    } else {
        die "Unknown instruction: $instruction\n";
    }

    $func->($data->{$ip});
    $ip++;
}

sub pinit {
    $CLIENT = new IO::Socket::INET (
        PeerHost => $HOST,
        PeerPort => $PORT,
        Proto => $PROTO,
    );
    die "cannot connect to the server $!\n" unless $CLIENT;
    print "Log: $PROTO connection to $HOST:$PORT established\n";
}

sub psend {
    my $data = shift;

    my $size = $CLIENT->send($data);
    print "Log: $size bytes sent to server\n$data\n"
}

sub precv {
    my $data = shift;

    my $buff;
    while(length $data != length $buff) {
        $CLIENT->recv($buff, 1024);
    }
    if ($buff =~ /$data/) {
        print "Log: Data received:\n$buff\n";
    } else {
        die "Error: Unexpected Response\n";
    }
}

sub pend {
    $CLIENT->close();
}

sub parse_description {
    my $protoDescFile = shift;
    open(my $fh, '<', $protoDescFile) || die "Can not open .proto specification file\n";

    my @_instructions;
    my %_data;
    my $_ip = 0; # instruction pointer
    my $dataFlag = 0;
    foreach my $line (<$fh>) {
        if($line =~ /$CONTROL_FIELD_RECV|$CONTROL_FIELD_SEND|$CONTROL_FIELD_END/) {
            chomp $line;
            if ($dataFlag == 1) {
                $_ip++;
                $dataFlag = 0;
            }
            $dataFlag = 1;
            push @_instructions, $line;
        } else {
            $_data{$_ip} .= $line;
        }
    }

    # Validate proto
    unless ($_instructions[$#_instructions] =~ /$CONTROL_FIELD_END/) {
        die "Last instruction must be 'end:'\n";
    }

    return {
        instructions => \@_instructions,
        data => \%_data,
    };
}

sub help {

}
