use strict;
use warnings;
use File::Find;
use Class::Struct;
use Getopt::Long;

binmode(STDOUT, ':encoding(UTF-8)');
binmode(STDERR, ':encoding(UTF-8)');
binmode(STDIN,  ':encoding(UTF-8)');

use constant {
    FUNC => 'Func',
    CPU_TIME => 'CpuTime',
    PROCESS_NAME => 'p:processName',
    COMPUTER_NAME => 't:computerName',
    APPLICATION_NAME => 't:applicationName',
    MODULE => 'Module',
    METHOD => 'Method',
    CONTEXT => 'Context',
    I_NAME => 'IName',
    M_NAME => 'MName'
};

struct EventCall => {
    descr => '$',
    process_name => '$',
    computer_name => '$',
    application_name => '$',
    func => '$',
    module => '$',
    method => '$',
    context => '$',
    i_name => '$',
    m_name => '$',
    cpu => '$'
};

sub EventCallNew {
    my $event_call = EventCall->new();
    $event_call->descr('');
    $event_call->process_name('');
    $event_call->computer_name('');
    $event_call->application_name('');
    $event_call->module('');
    $event_call->method('');
    $event_call->m_name('');
    $event_call->cpu(0);
    return $event_call;
}

sub tj_to_print_format {
    my ($date) = @_;
    $date =~ /^(\d{2})(\d{2})(\d{2})(\d{2}):(\d{2})$/;
    return "$3-$2-$1 $4:$5";
}

sub print_to_tj_format {
    my ($date) = @_;
    $date =~ /^(\d{2})-(\d{2})-(\d{2}) (\d{2}):(\d{2})$/;
    return "$3$2$1$4:$5";
}

sub usage {
    print <<"END_USAGE";
Usage: $0 [options]

Options:
  --help              Show this help message
  --dir=DIR           Directory to search (default: .)
  --fmt=FORMAT        File format: txt, html (default: txt)
  --cpu-cum-lt=FLOAT  Max CPU cumulative value (default: 100.0)
  --date-ge=DATE      Start date, format: DD-MM-YY HH:MM (default: no filter)
  --date-le=DATE      End date, format: DD-MM-YY HH:MM (default: no filter)
  --title=TITLE       Title filter (default: empty)

Examples:
  $0 --dir=/var/log --fmt=txt --cpu-cum-lt=80
END_USAGE
  exit 0;
}
usage() unless @ARGV;

my %settings = (
    dir => '.',
    fmt => 'txt',
    cpu_cum_lt => 100.0,
    date_ge => '00-00-00 00:00',
    date_le => '99-99-99 99:99',
    title => '',
);
my $help = 0;
GetOptions(
    'help|?' => \$help,
    'dir=s' => \$settings{dir},
    'fmt=s' => \$settings{fmt},
    'cpu-cum-lt=f' => \$settings{cpu_cum_lt},
    'date-ge=s' => \$settings{date_ge},
    'date-le=s' => \$settings{date_le},
    'title=s' => \$settings{title},
) or usage();
usage() if $help;
$settings{date_ge} = print_to_tj_format($settings{date_ge});
$settings{date_le} = print_to_tj_format($settings{date_le});

my %data;
my $total_cpu = 0;
my $total_count = 0;
my $date_min = '99999999:99';
my $date_max = '00000000:00';

my @files; find(sub {push @files, $File::Find::name if -f $_}, $settings{dir} );
foreach my $file (@files) {
    open(my $fn, '<:encoding(UTF-8)', $file) or die "No open file '$file':$!";
    while(my $line = <$fn>) {
        my $date = substr($line, 0, 11);
        next if ($date lt $settings{date_ge} || $date gt $settings{date_le});
        my @events = split /,/, $line;
        if ($events[1] eq "CALL") {
            if ($date lt $date_min) {$date_min = $date};
            if ($date gt $date_max) {$date_max = $date};
            my $event_call = EventCallNew();
            foreach my $i (3 .. @events) {
                next unless defined $events[$i];
                my @key_value = split /=/, $events[$i];
                #next unless defined $key_value[0] && defined $key_value[1];
                if ($key_value[0] eq PROCESS_NAME) {
                    $event_call->process_name($key_value[1]);
                } elsif ($key_value[0] eq COMPUTER_NAME) {
                    $event_call->computer_name($key_value[1]);
                } elsif ($key_value[0] eq APPLICATION_NAME) {
                    $event_call->application_name($key_value[1]);
                } elsif ($key_value[0] eq FUNC) {
                    $event_call->func($key_value[1]);
                } elsif ($key_value[0] eq MODULE) {
                    $event_call->module($key_value[1]);
                } elsif ($key_value[0] eq METHOD) {
                    $event_call->method($key_value[1]);
                } elsif ($key_value[0] eq CONTEXT) {
                    $event_call->context($key_value[1]);
                } elsif ($key_value[0] eq I_NAME) {
                    $event_call->i_name($key_value[1]);
                } elsif ($key_value[0] eq M_NAME) {
                    $event_call->m_name($key_value[1]);
                } elsif ($key_value[0] eq CPU_TIME) {
                    $event_call->cpu($key_value[1] + 0);
                }
            }

            next if $event_call->cpu() == 0;

            $total_cpu += $event_call->cpu();
            $total_count += 1;
            if (defined $event_call->func()) {
                $event_call->descr(join('', $event_call->process_name(), ";", $event_call->func(), ";", $event_call->module(), ".", $event_call->method()));
            } elsif (defined $event_call->context()) {
                $event_call->descr(join('', $event_call->process_name(), ";", $event_call->application_name(), ": ",$event_call->context()));
            } elsif (defined $event_call->i_name()) {
                $event_call->descr(join('', $event_call->process_name(), ";", $event_call->application_name(), ";", $event_call->i_name(), ".", $event_call->m_name()));
            } else {
                print "error!\n";
            }

            $data{$event_call->descr()}{count}++;
            $data{$event_call->descr()}{sum} += $event_call->cpu();
        }
    }
    close($fn);
}

my @sorted = sort { $data{$b}{sum} <=> $data{$a}{sum} } keys %data;
if ($settings{fmt} eq 'txt') {
    print "$settings{title}\n" if $settings{title}; 
    print "CALL Event Analysis\n";
    printf "Period: %s - %s\n", tj_to_print_format($date_min), tj_to_print_format($date_max);
    printf "Total count: %d;Total CPU: %d\n", $total_count, $total_cpu;
    print "Description;Count;Cpu;Cpu %;Cpu cumulative %\n";
    my $cumulative_percent = 0;
    foreach my $key (@sorted) {
        my $count = $data{$key}{count};
        my $sum   = $data{$key}{sum};
        my $percent = ($sum/$total_cpu) * 100;
        $cumulative_percent += $percent;
        printf "%s;%s;%d;%.2f;%.2f\n", $key, $count, $sum, $percent, $cumulative_percent;
        last if ($cumulative_percent >= $settings{cpu_cum_lt});
    }
} elsif ($settings{fmt} eq 'html') {
    print "<style>
    .report-container {
        font-family: Arial, sans-serif;
        margin: 20px;
    }
    .report-info {
        margin-bottom: 20px;
        padding: 10px;
        background-color: #f5f5f5;
        border-left: 4px solid #4CAF50;
    }
    .data-table {
        border-collapse: collapse;
        width: 100%;
    }
    .data-table th {
        background-color: #d3d3d3;
        font-weight: bold;
        padding: 8px;
        text-align: left;
    }
    .data-table td {
        padding: 8px;
        text-align: left;
    }
    .data-table tr:nth-child(even) {
        background-color: #f9f9f9;
    }
    .data-table tr:hover {
        background-color: #f5f5f5;
    }
    </style>\n";

    # Начало HTML контейнера
    print "<div class='report-container'>\n";
    
    # Информация о периоде и итогах (текст перед таблицей)
    print "<div class='report-info'>\n";
    print "$settings{title}<br>\n" if $settings{title}; 
    print "CALL Event Analysis<br>\n";
    printf "Period: %s - %s<br>\n", tj_to_print_format($date_min), tj_to_print_format($date_max);
    printf "Total count: %d; Total CPU: %d\n", $total_count, $total_cpu;
    print "</div>\n";
    
    # Начало таблицы
    print "<table class='data-table' border='1' cellpadding='5' cellspacing='0'>\n";
    
    # Заголовки таблицы (серый цвет)
    print "<thead>\n";
    print "<tr style='background-color: #d3d3d3;'>\n";
    print "<th>Description</th>\n";
    print "<th>Count</th>\n";
    print "<th>Cpu</th>\n";
    print "<th>Cpu %</th>\n";
    print "<th>Cpu cumulative %</th>\n";
    print "</tr>\n";
    print "</thead>\n";
    
    # Тело таблицы
    print "<tbody>\n";
    my $cumulative_percent = 0;
    foreach my $key (@sorted) {
        my $count = $data{$key}{count};
        my $sum   = $data{$key}{sum};
        my $percent = ($sum/$total_cpu) * 100;
        $cumulative_percent += $percent;
        
        printf "<tr>\n";
        printf "<td>%s</td>\n", $key;
        printf "<td>%s</td>\n", $count;
        printf "<td>%d</td>\n", $sum;
        printf "<td>%.2f</td>\n", $percent;
        printf "<td>%.2f</td>\n", $cumulative_percent;
        printf "</tr>\n";
        
        last if ($cumulative_percent >= $settings{cpu_cum_lt});
    }
    print "</tbody>\n";
    print "</table>\n";
    print "</div>\n";
}