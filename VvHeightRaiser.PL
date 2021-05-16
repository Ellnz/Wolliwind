# run via [tes3cmd modify -program ThisFile.pl]

my $original = "Morrowind.esm";
my $modified = "RaisedHeightMW.esp";

#my $original = "Morrowind.esm";
#my $modified = "RaisedHeightMW.esp";


my %first_cells = map {$_, 1700} (
    '(2, 10)',
    '(3, 10)',
    '(4, 10)',
    '(1, 9)',
    '(2, 9)',
    '(3, 9)',
    '(4, 9)',
	'(4, 8)',
	'(4, 7)',
    '(1, 8)',
    '(2, 8)',
    '(3, 8)',
    '(1, 7)',
    '(2, 7)',
    '(3, 7)',
);

my %second_cells = map {$_, 1350} (
	'(-2, 9)',	
	'(-2, 10)',
	'(-1, 11)',
	'(-1, 10)',
	'(-1, 9)',
	'(-1, 8)',
	'(0, 11)',
	'(0, 10)',
	'(0, 9)',
	'(0, 8)',
	'(0, 7)',
	'(0, 6)',
	'(1, 6)',
	'(1, 11)',
	'(1, 10)',
	'(2, 11)',
	'(2, 6)',
	'(3, 11)',
	'(3, 12)',
	'(3, 6)',
	'(4, 11)',
	'(4, 12)',
	'(4, 6)',
	'(5, 6)',
	'(5, 11)',
	'(5, 10)',
	'(5, 9)',
	'(5, 8)',
	'(5, 7)',
);

my %third_cells = map {$_, 1000} (
	'(-3, 11)',
	'(-3, 10)',
	'(-3, 9)',
	'(-2, 12)',
	'(-2, 11)',
	'(-2, 8)',
	'(-1, 12)',
	'(-1, 7)',
	'(-1, 6)',
	'(0, 12)',
	'(0, 5)',
	'(1, 12)',
	'(1, 4)',
	'(1, 5)',
	'(2, 12)',
	'(2, 5)',
	'(2, 4)',
	'(3, 5)',
	'(3, 13)',
	'(3, 4)',
	'(4, 5)',
	'(4, 13)',
	'(5, 12)',
	'(5, 13)',
	'(5, 5)',
	'(6, 12)',
	'(6, 11)',
	'(6, 10)',
	'(6, 13)',
	'(6, 9)',
	'(6, 8)',
	'(6, 7)',
	'(6, 6)',
);

my %fourth_cells = map {$_, 500} (
	'(-5, 13)',
	'(-5, 12)',
	'(-5, 11)',
	'(-5, 10)',
	'(-5, 9)',
	'(-5, 8)',
	'(-5, 7)',
	'(-5, 6)',
	'(-4, 14)',
	'(-4, 13)',
	'(-4, 12)',
	'(-4, 11)',
	'(-4, 10)',
	'(-4, 9)',
	'(-4, 8)',
	'(-4, 7)',
	'(-4, 6)',
	'(-4, 5)',
	'(-3, 14)',
	'(-3, 13)',
	'(-3, 12)',
	'(-3, 8)',
	'(-3, 7)',
	'(-3, 6)',
	'(-3, 5)',
	'(-3, 4)',
	'(-2, 14)',
	'(-2, 13)',
	'(-2, 7)',
	'(-2, 6)',
	'(-2, 5)',
	'(-2, 4)',
	'(-1, 13)',
	'(-1, 5)',
	'(-1, 4)',
	'(-1, 3)',
	'(0, 13)',
	'(0, 4)',
	'(0, 3)',
	'(0, 2)',
	'(1, 13)',
	'(1, 3)',
	'(1, 2)',
	'(2, 2)',
	'(2, 14)',
	'(2, 13)',
	'(2, 3)',
	'(3, 14)',
	'(3, 3)',
	'(4, 14)',
	'(4, 4)',
	'(5, 14)',
	'(6, 14)',
	'(6, 5)',
	'(6, 4)',
	'(7, 14)',
	'(7, 13)',
	'(7, 12)',
	'(7, 11)',
	'(7, 10)',
	'(7, 9)',
	'(7, 8)',
	'(7, 7)',
	'(7, 6)',
	'(7, 5)',
	'(7, 4)',
	'(8, 4)',
);


my $input = open_for_input($original);
my $output = open_for_output($modified);
print $output make_header();


while (my $record = TES3::Record->new_from_input($input)) {
    my $modified = 0;

    if ($record->rectype eq 'LAND') {
        $modified = apply_landscape_offsets($record);
    }
    elsif ($record->rectype eq 'CELL') {
        $modified = apply_reference_offsets($record);
    }
    elsif ($record->rectype eq 'LTEX') {
        $modified = 1;
    }

    if ($modified) {
        $record->write_rec($output);
    }
}


sub apply_landscape_offsets {
    my $record = shift;
    my $id = $record->decode->id;

    my $offset = $first_cells{$id} || $second_cells{$id} || $third_cells{$id} || $fourth_cells{$id};
    return unless defined $offset;

    my $VHGT = $record->get('VHGT');
    $VHGT->{offset} += $offset;
    $record->encode;
    return 1;
}


sub apply_reference_offsets {
    my $record = shift;
    my $id = $record->decode->id;
    return if $record->is_interior;
    return if $id !~ /(\(-?\d+, -?\d+\))$/;  # unable to get coordinates suffix from cell id

    my $offset = $first_cells{$1} || $second_cells{$1} || $third_cells{$1} || $fourth_cells{$1};
    return unless defined $offset;

    # loop through cell references
    my @groups = @{ $record->split_groups };
    while (my ($i, $group) = each @groups) {
        # create subrecord mapping
        my %subrecs = map {substr(ref $_, 6), $_} @$group;
        # get references name/data
        my $reference_name = $subrecs{NAME}{name};
        my $reference_data = $subrecs{DATA};
        # apply z position offsets
        if ($reference_name and $reference_data) {
            $subrecs{FRMR}{mastidx} = 1;  # assign to first master file
            my $old_z = $reference_data->{z};
            $reference_data->{z} += $offset * 8;
            my $new_z = $reference_data->{z};
            print "$id : $reference_name, $old_z -> $new_z\n";
        }
    }
    $record->encode;
    return 1;
}


exit;

