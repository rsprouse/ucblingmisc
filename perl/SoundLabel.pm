# SoundLabel.pm - module for handling label files from various
# speech applications
#
# Authors: Ronald L. Sprouse (ronald@berkeley.edu)
# 
# Copyright (c) 2014, The Regents of the University of California
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
# 
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# 
# * Neither the name of the University of California nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Original version written in 2008. Various updates since then.

# To install this module, copy it to one of Perl's @INC directories.
# Alternatively, place it in the same directory as any Perl script that
# imports it.

package SoundLabel;

use strict;
use warnings;
use constant(DEFAULT_TIER => 1);
use Carp;
use FileHandle;

use vars qw($AUTOLOAD $VERSION);
## TODO: add $VERSION information

=head1 NAME

SoundLabel - Object-oriented Perl module for reading/writing/converting
label files produced by audio software, e.g. ESPS/Xwaves, Praat, Wavesurfer.

=head1 SYNOPSIS


  use SoundLabel;

=head2 Iteration

  # read an esps file and iterate over the labels
  my $label = SoundLabel->new($labelfile, 'esps');
  while ( defined $label->next() ) {
    if ($label->content() =~ /some_string/) {
      print "Start: ",    $label->start(),    "\n";
      print "End: ",      $label->end(),      "\n";
      print "Duration: ", $label->duration(), "\n";
      print "Text: ",     $label->content(),     "\n";
    }
  }

=head2 File conversion

  # read Praat TextGrid file and output tier 5 to esps format
  my $label = SoundLabel->new($labelfile,'praat');
  $output = $label->stringify_as('esps', 5);
  print $output;

Or all in one go:

  print SoundLabel->new($labelfile,'praat')->stringify_as('esps',5);

The 'all-in-one-go' version is handy for writing one-line
label file converters, e.g.:

  perl -MSoundLabel -e "print SoundLabel->new('myfile.TextGrid','praat')->stringify_as('esps',1)" > myoutput.label

=head1 DESCRIPTION

SoundLabel provides an easy way to parse audio software label files,
which can then be used to 1) iterate over all the labels; or
2) be converted to a different format.

=head1 FEATURES

=over 2

=item *

Planned support for reading/writing multiple label file formats.
Current support includes: read Praat TextGrid files
('praat' format), partial read/write Praat TextGrid files in short format
('praat_short' format; does read multiple tiers; writes multiple tiers?),
read/write Wavesurfer label files ('wavesurfer' format), and read/write
ESPS/Xwaves label files ('esps' format). See the label format sections
for details.

=over 2

=item 1
C<esps> ESPS/Xwaves label files

=item 2
C<praat> Praat TextGrid files

=item 3
C<praat_short> Praat TextGrid short text files

=item 4
C<wavesurfer> Wavesurfer label files

=back


=item *

Iteration over the labels in a file and extraction of the
times and contents of each labelled region.

=back

=cut

my %Filetypes = ( # label styles that I can handle
  praat        => # Praat TextGrid
    { 
      reader => \&_read_praat,
      writer => \&_write_praat,
    },
  praat_short  => # Praat TextGrid (short text file)
    {
      reader => \&_read_praat_short,
      writer => \&_write_praat_short,
    },
  wavesurfer   => # Wavesurfer
    {
      reader => \&_read_wavesurfer,
      writer => \&_write_wavesurfer,
    },
  esps         => # ESPS (aka XWaves, Waves+)
    {
      reader => \&_read_esps,
      writer => \&_write_esps,
    },
);

=pod
=head1 CONSTRUCTOR

Use C<new()> to create a SoundLabel object. Pass the
label file to be read as the first argument, and pass the
filetype as the second argument. Valid 
filetypes for reading are: 'praat' and 'praat_short', for Praat
TextGrid objects; 'esps' for ESPS/Waves label files created by xlabel;
'wavesurfer' for Wavesurfer label files.

Example:

  my $label = SoundLabel->new($file,$type);

You may also pass an optional third argument, which contains
a hashref of parameters that affect the behavior of the reader.
Currently, only the esps reader makes use of this feature, and
it only makes use of only one parameter, 'parse_content', which
tells the reader whether the label content should be split into
separate tiers if the 'separator' field is defined in the label
file header. This parameter defaults to a true value. Set it
to a false value if you don't want to split the label content
into separate tiers.

Example:

  my $label = SoundLabel->new($file,'esps',{parse_content => 0});

=cut

sub new {
   my $that       = shift;
   my $class      = ref($that) || $that;
   my $labelfile  = shift;
   my $filetype   = shift;

   croak "I don't know that filetype!\n" unless exists $Filetypes{$filetype};

   my $fh;
   open($fh,$labelfile) or croak "Can't open label file $labelfile: $!"; 
   # pass any remaining arguments to the reader
   my $self = $Filetypes{$filetype}{reader}->($fh,@_);
   close $fh;

   if (keys %$self) {
      bless $self, $class;
      return $self;
   }
   else {
      return undef;
   }
}

=pod

=head1 NOTES ON FILE READERS

=head2 Praat TextGrid reader

The current state of the Praat TextGrid reader is 'quick-n-dirty':
  - ignores header information
  - doesn't distinguish point tiers and duration tiers
  - slurps entire label file, so could take a large amount of
      memory if your label file is very long (probably not a
      problem in most situations)

=cut

# TODO clean this up to use methods instead of working with the data
# structure directly
sub _read_praat {  # Deduce type of praat label file format and read.
   my $file = shift;
   my $first = <$file>;
   my $label;
   if ($first =~ /short/i) {
     $label = _read_praat_short($file, $first, @_);
   }
   else {
     $label = _read_praat_long($file, $first, @_);
   }
   return $label;
}

# Read praat's long textgrid format.
sub _read_praat_long {  # read a Praat label file
   my $file = shift;
   my $firstline = shift || '';

   my %label;

   local $/;
   my $text = <$file>;
   chomp $text;
   $text =~ s/\cM//g; # for accessing files on FAT filesystem
   my ($head,$rest) = split /\nitem \[\]:\s*\n    item \[1\]:/, $text; 
   $head = $firstline . $head;
   my @item = split /\n    item \[\d+\]:\s*\n/, $rest;
   my $tier = 1;
   foreach (@item) {
      my ($meta,@int) = split /\n        (?:intervals|points) \[\d+\]:/;
# This doesn't handle multiline text entries (i.e. with linebreaks)
#      foreach (@int) {
#	 my %entry;
#         ($entry{end})   = /\n            (?:xmax|time) = ([\d.]*)/g;
#         ($entry{content})  = /\n            (?:text|mark) = "(.*)"/g;
#	 $entry{content} =~ s/""/"/g;  # double quotes are escaped with "
#         push @{$label{$tier}}, \%entry;
#      }
      my $first_interval = 1;
      foreach (@int) {
	 my %entry;
         my ($toss, $xmax_and_content, $end, $content);
         # This is a bit of a hack to work around deficiencies in the data model
         if ($first_interval) {
           /xmin =\s+(?<start>[\d.]+)/;
           push @{$label{$tier}}, {end => $+{start}, content => ''};
           $first_interval = 0;
         }
         ($toss,$xmax_and_content) = split(/\n            (?:xmax|time) = /);
         ($end, $content) = split(/\s*\n\s*/, $xmax_and_content);
         $content =~ s/^text\s*=\s*"|"\s*$//msg;
         $content =~ s/""/"/msg;  # double quotes are escaped with "
         $entry{end} = $end;
         $entry{content} = $content;
         push @{$label{$tier}}, \%entry;
      }
      $label{tier_iterator_idx}{$tier} = undef;
      $tier++;
   }
   return \%label;
}

=pod

=head2 Praat Short TextGrid reader

The current state of the Praat Short TextGrid reader is 'quick-n-dirty':
  - Handles reading multiple tiers
  - Handles writing multiple tiers??
  - ignores header information
  - doesn't distinguish point tiers and duration tiers
  - slurps entire label file, so could take a large amount of
      memory if your label file is very long (probably not a
      problem in most situations)

=cut

# TODO clean this up to use methods instead of working with the data
# structure directly
sub _read_praat_short {  # read a Praat label file
   my $file = shift;
   my $firstline = shift || '';

   my %label;

   local $/;
   my $text = <$file>;
   chomp $text;
   $text =~ s/\cM//g; # for accessing files on FAT filesystem
   my ($head,@tiers) = split /\n"(?:Tier1|IntervalTier)"\s*\n(?:\s*"\w+"\s*\n)?(?:(?:\d+(?:\.\d+)?\s*\n){3})/, $text; 
   $head = $firstline . $head;
   #my @tiers = split /\n"(?:Tier1|IntervalTier)"\s*\n(?:\s*"\w+"\s*\n)?(?:(?:\d+(?:\.\d+)?\s*\n){3})/, $rest; 
   my $tier = 1;
   foreach my $tierstr (@tiers) {
     my $first_interval = 1;
     until (not $tierstr) {
        my ($start,$end,$content);
        $tierstr =~ s/(\d+(?:\.\d+)?)\s*\n//;
        $start = $1;
        # This is a bit of a hack to work around deficiencies in the data model
        if ($first_interval) {
          push @{$label{$tier}}, {end => $start, content => ''};
          $first_interval = 0;
        }
        $tierstr =~ s/(\d+(?:\.\d+)?)\s*\n//;
        $end = $1;
        $tierstr =~ s/"([^\n]*)"\s*\n?//;
        $content = $1;
        $content =~ s/""/"/g;  # double quotes are escaped with "
        my %entry;
        $entry{end} = $end;
        $entry{content} = $content;
        push @{$label{$tier}}, \%entry;
        $label{tier_iterator_idx}{$tier} = undef;
     }
     $tier++;
   }
   return \%label;
}

=pod

=head2 Wavesurfer reader

The current state of the Wavesurfer reader is 'quick-n-dirty':
  - based on a single label file, which might be missing some features
    found in other label files (i.e. the reader might be incomplete)
  - assumes that end time of interval n = start time of interval n+1
  - assumes that there is only one tier

=cut

# TODO clean this up to use methods instead of working with the data
# structure directly
sub _read_wavesurfer {  # read a Wavesurfer label file
   my $file = shift;
   my %label;
   my $tier = 1;
   while (<$file>) {
      chomp;
      my ($start,$end,$content) = split / /, $_, 3;
      push @{$label{$tier}}, {end => $end, content => $content}; 
   }
   $label{tier_iterator_idx}{$tier} = undef;
   return \%label;
}

=head2 ESPS reader

The ESPS reader
  - if 'nfields' and 'separator' are defined in the header, splits each
      label text into fields using 'separator' as the delimiter. Each
      of these fields is treated as a separate label tier. ** UNTESTED **
  - keeps an in-memory copy of the entire label file, so could take a
      large amount of memory if your label file is very long (probably
      not a problem in most situations)
  - retains only the information found in the last instance of
      a header line (probably only significant for 'comment' lines --
      other header parameter lines probably don't appear multiple times)
  - doesn't retain the labels' colormap property
  - does the pedantic thing and sorts label entries by time since the
      esps documentation explicitly states that chronological order
      is not required by the file format, even though in practice
      xlabel always produces label files in chronological order

=cut

# TODO clean this up to use methods instead of working with the data
# structure directly
# _read_esps($filename)
# _read_esps($filename,$paramsref)
# $paramsref is a hashref for named parameters, e.g.
#   {parse_content => 1}
sub _read_esps {
   my $file = shift;
   my %param = (
     parse_content    => 1,
     assume_no_header => 0,   # default to looking for a header
   );
   my $namedparam = shift;
   foreach my $key (%$namedparam) {
     $param{$key} = $namedparam->{$key};
   }

   my %head;
   my $found_header_separator = 0;
   while (<$file>) {
      $found_header_separator = 1, last if /^#/;
      chomp;
      my ($param,$val);
      # Workaround for some badly defined files.
      if (/separator;/) {
        ($param,$val) = ('separator', ';');
      } else {
        ($param,$val) = split /\s/, $_, 2;
      }
      ## TODO: this loses some information if there are multiple
      ## instances of a param in the header (e.g. multiple 'comment's
      ## in the header)
      $head{$param} = $val;
   }
   if (not $found_header_separator) {
      warn "Didn't find mandatory header separator line '#' in esps label file!";
      return undef;
   }
   $head{nfields} = 1 if not exists $head{nfields};
   my $line;
   my @int;
   while ( defined ($line = <$file>) ) {
      chomp $line;
      next if not $line;   # skip empty lines
      my ($junk,$end,$color,$content) = split /\s+/, $line, 4;
      my %entry;
      $entry{end} = $end;
      my @texttier;
      if ($param{parse_content} and exists $head{separator}) {
          if ($content) {
              # Workaround for label files that don't have a trustworthy nfields value in the header.
              #@texttier = split /$head{separator}/, $content, $head{nfields};
              @texttier = split /$head{separator}/, $content;
          } else {
              @texttier = $content;
          }
      } else {
         @texttier = $content;
      }
      $entry{texttier} = \@texttier;
      push @int, \%entry;
   }
   @int = sort {$a->{end} <=> $b->{end}} @int;
   my %label;
   foreach my $interval (@int) {
      my $tier = 1;
      foreach my $text ( @{$interval->{texttier}} ) {
         push @{$label{$tier}}, {
	    end => $interval->{end},
	    content => $text,
         };
         $label{tier_iterator_idx}{$tier} = undef;
         $tier++;
      }
   }
   return \%label;
}

=pod

=head1 METHODS

=cut



=pod

=head2 C<stringify_as()>

Use C<stringify_as()> to retrieve a string containing the label
information in a designated file format.

Specify the desired format as the first argument. The optional
second argument allows you to select a specific input tier number
for output. This argument is useful if you need to convert an input
format like a Praat TextGrid, which can have multiple annotation
tiers, to an output format like ESPS, which does not. Only the
selected tier will be processed.

The currently-supported formats for C<stringify_as> are 'esps', 
'wavesurfer', and  support for 'praat_short'. The 'praat' output
format is not yet implemented.

Example:

  my $output = $label->stringify_as('esps',$tier);
  print $output;

=cut

sub stringify_as {
  my $self = shift;
  my $filetype = shift;
  my $string;
  if ($filetype =~ /praat/) {
    my @tiers = @_;
    push @tiers, (1 .. $self->num_tiers()) if scalar(@tiers) == 0;
    $string = $Filetypes{$filetype}{writer}->($self,@tiers);
  }
  else {
    my $tier     = shift || DEFAULT_TIER;
    my $save_idx = $self->_tier_iterator_idx($self,$tier);
    $string = $Filetypes{$filetype}{writer}->($self,$tier);
    $self->reset($tier);
    $self->_tier_iterator_idx($self,$tier,$save_idx);
  }
  return $string;
}

=pod

=head2 C<write_to_file($filename, $filetype, $tier)>

Use C<write_to_file($filename, $filetype, $tier)> to write $tier to $filename
using $filetype. If $file is 'STDOUT', print to STDOUT.

Example:

  $label->write_to_file($filename,'esps',$tier);

=cut

sub write_to_file {
  my $self = shift;
  my $filename = shift;
  my $filetype = shift;
  my $tier     = shift || DEFAULT_TIER;
  my $fh;
  if ($filename eq 'STDOUT') {
    print STDOUT $self->stringify_as($filetype, $tier);
  }
  else {
    $fh = FileHandle->new($filename, "w");
    print $fh $self->stringify_as($filetype, $tier);
    if (defined $fh) {
      $fh->close();
    }
    else {
      return undef;
    }
  }
}

sub _write_praat {
  warn "_write_praat method not implemented!\n";
}

# quick-n-dirty output for wavesurfer files
# - not really sure this is correct
# - can't handle multiple tiers
# - assumes labels are ordered chronologically
sub _write_wavesurfer {
  my $self = shift;
  my $tier = shift;
  my $output = "";
  while (defined($self->next($tier))) {
    $output .= join("\t", $self->start($tier), $self->end($tier), $self->content($tier)) . "\n";
  }
  return $output;
}

# quick-n-dirty output for esps label files
# - no header (not required)
# - can't handle multiple tiers (e.g. Praat TextGrid tiers)
# - assumes labels are ordered chronologically
# - uses default color value
sub _write_esps {
  my $self = shift;
  my $tier = shift;
  my $color = '121'; # default in xwaves?
  my $output = "#\n";
  while (defined($self->next($tier))) {
    $output .= " " .
               $self->end($tier) .
               " $color " .
               $self->content($tier) .
               "\n";
  }
  return $output;
}

# quick-n-dirty output for praat short label files
# - can only interval tiers
# - automatically names tier "Tier1"
# - assumes labels are ordered chronologically
sub _write_praat_short {
  my $self = shift;
  my @tiers = @_;

  my $num_tiers = scalar(@tiers);
  my $filestart;
  my $fileend;
  foreach my $tier (@tiers) {
    if (not defined $filestart or $filestart > $self->tier_start($tier)) {
      $filestart = $self->tier_start($tier);
    }
    if (not defined $fileend or $fileend < $self->tier_end($tier)) {
      $fileend = $self->tier_end($tier);
    }
  }

  my $output = "File type = \"ooTextFile short\"\nObject class = \"TextGrid\"\n\n";
  $output .= "$filestart\n";
  $output .= "$fileend\n";
  $output .= "<exists>\n";
  $output .= "$num_tiers\n";
  foreach my $tier (@tiers) {
    $output .= "\"IntervalTier\"\n";
    $output .= "\"Tier$tier\"\n";
    $output .= "$filestart\n";
    $output .= "$fileend\n";
    $output .= $self->num_labels($tier) . "\n";
  
    while (defined($self->next($tier))) {
      my $content = $self->content($tier);
      $content =~ s/"/""/g;
      $output .= $self->start($tier) . "\n" .
                 $self->end($tier) . "\n" .
  	       "\"$content\"\n";
    }
  }
  return $output;
}

=pod

=head2 C<next()>

Use the C<next()> method as an iterator to work your way
through a label tier. Every time you advance to a new label
region, pull data from the label with the C<start>,
C<end>, and C<content> methods.

If no tier number is supplied, C<next()> defaults to
the first tier.

Example:

  my $label = SoundLabel->new($labelfile, $type);
  while ( defined $label->next($tiernum) ) {
    print "Start: ",    $label->start($tiernum),    "\n";
    print "End: ",      $label->end($tiernum),      "\n";
    print "Duration: ", $label->duration($tiernum), "\n";
    print "Text: ",     $label->content($tiernum),     "\n";
  }

Note that after you have created a SoundLabel object, you
must make at least one call to C<next()> before you can
read text or start/end times from a label tier.

Returns C<undef> if you attempt to C<next()> past the
last label of the specified tier. The iterator will also
reset in this circumstance.

=cut

sub next {
  my $self = shift;
  my $tier = shift || DEFAULT_TIER;
  my $idx = $self->_increment_tier_iterator_idx($tier);
  if ($idx < $self->num_labels($tier)) {
    return $idx;
  } else {
    $self->_reset_tier_iterator_idx($tier);
    return undef;
  }
}

=pod

=head2 C<prev()>

Use the C<prev()> method as an iterator to work your way
through a label tier in reverse. Every time you move to a new label
region, pull data from the label with the C<start>,
C<end>, and C<content> methods.

If no tier number is supplied, C<prev()> defaults to the first tier.

Example:

  my $label = SoundLabel->new($labelfile, $type);
  while ( defined $label->prev($tiernum) ) {
    print "Start: ",    $label->start($tiernum),    "\n";
    print "End: ",      $label->end($tiernum),      "\n";
    print "Duration: ", $label->duration($tiernum), "\n";
    print "Text: ",     $label->content($tiernum),     "\n";
  }

Note that after you have created a SoundLabel object, you
must make at least one call to C<prev()> before you can
read text or start/end times from a label tier.

Returns C<undef> if you attempt to C<prev()> before the
first label of the specified tier. The iterator will also
reset in this circumstance.

=cut

sub prev {
  my $self = shift;
  my $tier = shift || DEFAULT_TIER;
  my $idx = $self->_decrement_tier_iterator_idx($tier);
  if (defined $idx) {
    return $idx;
  } else {
    $self->_reset_tier_iterator_idx($tier);
    return undef;
  }
}

=pod

=head2 C<delete()>

Use the C<delete()> method to remove the current label.
Deleting a label also moves the iterator backwards so that the
next label will be made current after the next call to next().
This makes it safe to delete() in a next() loop without skipping
labels.

NOTE: To avoid skipping in a prev() loop you must call next()
before calling prev() again.

Example:

  my $label = SoundLabel->new($labelfile, $type);
  while ( defined $label->next($tiernum) ) {
    $label->delete() if $label->end() < 5;
  }

  my $label = SoundLabel->new($labelfile, $type);
  while ( defined $label->prev($tiernum) ) {
    $label->delete() if $label->end() < 5;
    $label->next();
  }

Note that after you have created a SoundLabel object, you
must make at least one call to C<prev()> before you can
read text or start/end times from a label tier.

Returns C<undef> if you attempt to C<prev()> before the
first label of the specified tier. The iterator will also
reset in this circumstance.

=cut

sub delete {
  my $self = shift;
  my $tier = shift || DEFAULT_TIER;
  my $idx  = $self->_tier_iterator_idx($tier);
  my $last = $self->_last_tier_iterator_idx($tier);
  if (not defined $idx) {
    return undef;
  }
  elsif ($idx == 0) {
    @{$self->{$tier}} = @{$self->{$tier}}[1 .. $last];
    $self->_reset_tier_iterator_idx($tier);
  }
  elsif ($idx == $self->_last_tier_iterator_idx($tier)) {
    @{$self->{$tier}} = @{$self->{$tier}}[0 .. $last - 1];
    $self->prev($tier);
  }
  else {
    @{$self->{$tier}} = (
        @{$self->{$tier}}[0 .. $idx - 1],
        @{$self->{$tier}}[$idx + 1 .. $last]
      );
    $self->prev($tier);
  }
}

=pod

=head2 C<set_at_time($time,[$tier])>

Use the C<set_at_time($time,[$tier])> method to move the iterator
to the label corresponding to the point or interval given by $time
(in whatever time units are used by the label file).

Returns C<undef> if there is no point or interval corresponding to
$time, and the iterator does not move.

If $tier is not specified, defaults to the first tier.

Example:

  $label->set_at_time(15);  # set to interval around 15 seconds
  my $text = $label->content();

=cut

# This is a simple implementation. It could be useful to also
# implement alternative algorithms for use with large label
# files, but the current implementation is okay for small files.
# (It might be difficult to optimize anyway since label files
# aren't guaranteed to be without gaps or in chronological order.)
### NOTE: there is some ambiguity inherent in the situation in which
# $time falls exactly on a start/end boundary (which is shared by
# two intervals), and this code does not attempt to detect or resolve
# the ambiguity. It will return the interval in which $time
# falls on the start boundary.
sub set_at_time {
  my $self = shift;
  my $time = shift;
  my $tier = shift || DEFAULT_TIER;
  my $idx = $self->_tier_iterator_idx($tier);
  $self->reset($tier);
  # If $time isn't defined, then we return, having already reset the tier;
  # otherwise, we advance to the appropriate interval.
  if (defined $time) {
    while ( defined $self->next($tier) ) {
      return if $self->start($tier) == $time ||
                ($self->start($tier) < $time && $self->end($tier) > $time);
    }
    # restore if appropriate interval not found
    $self->_tier_iterator_idx($tier,$idx);
    return undef;
  }
  else {
    return undef;
  }
}

=pod

=head2 C<scale_by($factor,[$tier])>

Use the C<scale_by($factor,[$tier, $tierN...])> method to modify
start/end times of all intervals by multiplying by $factor.

Multiple tiers may be specified. If no tier is specified, then
all tiers will be scaled.

This method returns the _tier_iterator_idx to its original
location after the modifications are made.

Example:

  # Mulitply all start/end times in all tiers by 10.
  $label->scale_by(10);

=cut

sub scale_by {
  my $self = shift;
  my $factor = shift;
  $self->_scale_or_shift($factor, 'scale', @_);
}

=pod

=head2 C<shift_by($time,[$tier])>

Use the C<shift_by($time,[$tier, $tierN...])> method to modify
start/end times of all intervals by adding the specified $time.

Multiple tiers may be specified. If no tier is specified, then
all tiers will be shifted.

This method returns the _tier_iterator_idx to its original
location after the modifications are made.

Example:

  # Shift all start/end times in all tiers by 0.5.
  $label->shift_by(0.5);

=cut

sub shift_by {
  my $self = shift;
  my $time = shift;
  $self->_scale_or_shift($time, 'shift', @_);
}

=pod

=head2 C<reset()>

Use the C<reset()> method to reset the iterator used by
C<next()>.

C<reset()> can be useful if you break out of an
C<next()> loop early and want to loop through the
labels in a tier again.

Example:

  while ( defined $label->next($tiernum) ) {
    last if $label->content($tiernum) eq 'stop';
    # do something
  }

  $label->reset($tiernum);  # start again at the beginning

  while ( defined $label->next($tiernum) ) {
    # do something
  }

If no tier number is supplied, C<reset()> defaults to
the first tier.

=cut

sub reset {
  my $self = shift;
  my $tier = shift || DEFAULT_TIER;
  $self->_reset_tier_iterator_idx($tier);
}

=pod

=head2 C<first()>

Use the C<first()> method to move the iterator to the
first label in the tier.

Example:

  $label->first($tiernum);
  $tier_end = $label->end($tiernum);

If no tier number is supplied, C<first()> defaults to
the first tier.

=cut

sub first {
  my $self = shift;
  my $tier = shift || DEFAULT_TIER;
  $self->reset($tier);
  $self->next($tier);
}

=pod

=head2 C<last()>

Use the C<last()> method to move the iterator to the
last label in the tier.

Example:

  $label->last($tiernum);
  $tier_end = $label->end($tiernum);

If no tier number is supplied, C<last()> defaults to
the first tier.

=cut

sub last {
  my $self = shift;
  my $tier = shift || DEFAULT_TIER;
  $self->_set_last_tier_iterator_idx($tier);
}

=pod

=head2 C<end()>

Use the C<end()> method to get the end time of the
current label of the specified tier.

If no tier number is supplied, C<end()> defaults to
the first tier.

Returns C<undef> if the iterator has not yet C<next()>d to
the first label of the specified tier.

=cut

sub end {
  my $self = shift;
  my $tier = shift || DEFAULT_TIER;
  my $idx = $self->_tier_iterator_idx($tier);
  return defined $idx ?
                 $self->{$tier}[$idx]{end} :
		 undef;
}

=pod

=head2 C<start()>

Use the C<start()> method to get the start time of the
current label of the specified tier.

Note that C<start> assumes that the first label on a
tier always starts at 0. This behavior may not be correct
under all conditions.

If no tier number is supplied, C<start()> defaults to
the first tier.

Returns C<undef> if the iterator has not yet C<next()>d to
the first label of the specified tier.

=cut

sub start {
  my $self = shift;
  my $tier = shift || DEFAULT_TIER;
  my $idx = $self->_tier_iterator_idx($tier);
  my $start;
  if (not defined $idx) {
    $start = undef;
  } elsif ($idx > 0) {
    $start = $self->{$tier}[$idx-1]{end};
  } else {
    $start = 0;
  }
  return $start;
}

=pod

=head2 C<content()>

Use the C<content()> method to get the text content of the
current label of the specified tier.

If no tier number is supplied, C<content()> defaults to
the first tier.

Returns C<undef> if the iterator has not yet C<next()>d to
the first label of the specified tier.

=cut

sub content {
  my $self = shift;
  my $tier = shift || DEFAULT_TIER;
  my $idx = $self->_tier_iterator_idx($tier);
  return defined $idx ?
                 $self->{$tier}[$idx]{content} :
		 undef;
}

=pod

=head2 C<set_content($value,$tier)>

Use the C<set_content> method to set the text content of the
current label of the specified tier.

If no tier number is supplied, C<set_content()> defaults to
the first tier.

Returns the result of the assignment.

=cut

sub set_content {
  my $self = shift;
  my $value = shift;
  my $tier  = shift || DEFAULT_TIER;
  my $idx = $self->_tier_iterator_idx($tier);
  return $self->{$tier}[$idx]{content} = $value;
}

=pod

=head2 C<set_start($value,$tier)>

Use the C<set_start> method to set the value returned by start() of the
current label of the specified tier.

If no tier number is supplied, C<set_start()> defaults to
the first tier.

Returns the result of the assignment.

=cut

sub set_start {
  my $self = shift;
  my $value = shift;
  my $tier  = shift || DEFAULT_TIER;
  my $idx = $self->_tier_iterator_idx($tier);
  return $self->{$tier}[$idx]{start} = $value;
}

=pod

=head2 C<set_end($value,$tier)>

Use the C<set_end> method to set the value returned by end() of the
current label of the specified tier.

If no tier number is supplied, C<set_end()> defaults to
the first tier.

Returns the result of the assignment.

=cut

sub set_end {
  my $self = shift;
  my $value = shift;
  my $tier  = shift || DEFAULT_TIER;
  my $idx = $self->_tier_iterator_idx($tier);
  return $self->{$tier}[$idx]{end} = $value;
}

=pod

=head2 C<duration()>

Use the C<duration()> method to get the duration of the
current label of the specified tier.

If no tier number is supplied, C<duration()> defaults to
the first tier.

Returns C<undef> if the iterator has not yet C<next()>d to
the first label of the specified tier.

=cut

sub duration {
  my $self = shift;
  my $tier = shift || DEFAULT_TIER;
  my $start = $self->start($tier,$self->_tier_iterator_idx($tier));
  my $end   = $self->end($tier,$self->_tier_iterator_idx($tier));
  return undef unless defined($start) && defined($end);
  return $end-$start;
}

=pod

=head2 C<num_labels()>

Use the C<num_labels()> method to get the number of labels
contained in the specified tier.

If no tier number is supplied, C<duration()> defaults to
the first tier.

=cut

sub num_labels {
  my $self = shift;
  my $tier = shift || DEFAULT_TIER;
  return scalar @{$self->{$tier}};
}

=pod

=head2 C<tier_start()>

Use the C<tier_start()> method to get the start time of
the specified tier.

If no tier number is supplied, C<tier_start()> defaults to
the first tier.

If the $mode parameter is 'skipzero', then the start time of the
tier is taken as the end time of the first interval if the first
interval starts at 0.

=cut

sub tier_start {
  my $self = shift;
  my $tier = shift || DEFAULT_TIER;
  my $mode = shift || '';
  my $oldidx = defined $self->_tier_iterator_idx($tier) ?
                       $self->_tier_iterator_idx($tier) :
		       undef;
  $self->_tier_iterator_idx($tier, 0);
  my $start = $self->start($tier);
  if ($start == 0 and $mode eq 'skipzero') {
    $start = $self->end($tier);
  }
  $self->_tier_iterator_idx($tier, $oldidx);
  return $start;
}

=pod

=head2 C<tier_end()>

Use the C<tier_end()> method to get the end time of
the specified tier.

If no tier number is supplied, C<tier_end()> defaults to
the first tier.

=cut

sub tier_end {
  my $self = shift;
  my $tier = shift || DEFAULT_TIER;
  my $oldidx = defined $self->_tier_iterator_idx($tier) ?
                       $self->_tier_iterator_idx($tier) :
		       undef;
  $self->_set_last_tier_iterator_idx($tier);
  my $end = $self->end($tier);
  $self->_tier_iterator_idx($tier, $oldidx);
  return $end;
}

=pod

=head2 C<num_tiers()>

Use the C<num_tiers()> method to get the number of tiers
in the label file.

=cut

sub num_tiers {
  my $self = shift;
  my $a = 1;
  my $n = 0;
  foreach (keys %$self) {
    $n++ if /^\d+$/;
  }
  return $n;
}


#### Private methods for manipulating iterator indexes ####

# get/set value of tier iterator index of specified tier
sub _tier_iterator_idx {
  my $self = shift;
  my $tier = shift || DEFAULT_TIER;
  if (@_) {
    $self->{tier_iterator_idx}{$tier} = shift;
  }
  return $self->{tier_iterator_idx}{$tier};
}

# increment tier iterator index by 1
sub _increment_tier_iterator_idx {
  my $self = shift;
  my $tier = shift || DEFAULT_TIER;
  my $newidx = defined $self->_tier_iterator_idx($tier) ?
                       $self->_tier_iterator_idx($tier) + 1 :
		       0;
  return $self->_tier_iterator_idx($tier,$newidx);
}

# decrement tier iterator index by 1
sub _decrement_tier_iterator_idx {
  my $self = shift;
  my $tier = shift || DEFAULT_TIER;
  my $newidx;
  if (defined $self->_tier_iterator_idx($tier)) {
    if ($self->_tier_iterator_idx($tier) > 0) {
      $newidx = $self->_tier_iterator_idx($tier) - 1;
    }
    else {
      $newidx = undef;
    }
  }
  else {
    $newidx = $self->_set_last_tier_iterator_idx($tier);
  }
  return $self->_tier_iterator_idx($tier,$newidx);
}

# set tier iterator index to before first label
sub _reset_tier_iterator_idx {
  my $self = shift;
  my $tier = shift || DEFAULT_TIER;
  return $self->_tier_iterator_idx($tier,undef);
}

# get the idx of the last entry in the tier
sub _last_tier_iterator_idx {
  my $self = shift;
  my $tier = shift || DEFAULT_TIER;
  return $self->num_labels($tier) - 1;
}

# set tier iterator index to last label
sub _set_last_tier_iterator_idx {
  my $self = shift;
  my $tier = shift || DEFAULT_TIER;
  return $self->_tier_iterator_idx($tier, $self->_last_tier_iterator_idx($tier));
}

# Method for scaling all times by the given factor or shifting all times
# by the given amount. $mode determines whether to scale or shift. Private
# method used by scale_by() and shift_by().
sub _scale_or_shift {
  my $self = shift;
  my $num = shift;  # factor or amount to shift
  my $mode = shift; # 'scale' | 'shift'
  my @tiers = defined($_[0]) ? @_ : 1 .. $self->num_tiers();
  foreach my $tier (@tiers) {
    my $idx = $self->_tier_iterator_idx($tier);
    $self->reset($tier);
    while ( defined $self->next($tier) ) {
      if ($mode eq 'scale') {
        $self->set_start($self->start($tier) * $num, $tier);
        $self->set_end($self->end($tier) * $num, $tier);
      }
      elsif ($mode eq 'shift') {
        $self->set_start($self->start($tier) + $num, $tier);
        $self->set_end($self->end($tier) + $num, $tier);
      }
      else {
        return undef;
      }
    }
    # Restore _tier_iterator_idx to original setting
    $self->_tier_iterator_idx($tier,$idx);
  }
}

=pod

=head1 BUGS

C<start> assumes that the first label on any label tier starts
at 0, which may not be correct behavior in all circumstances but
is probably right most of the time.

Splitting of ESPS label text into tiers by the separator character
is untested.

There are doubtless many other bugs in the current implementation, which
is still fairly rudimentary. It's worth noting that label files are
slurped in their entirety and parsed in large chunks, so there's a
theoretical possibility that processing the files will take up a
lot of available memory. Given the size of most label files that I've
seen, however, it's unlikely that slurping the file will pose much
of a problem even on ordinary hardware.

=head1 TO DO

Develop a meta label standard that can ably represent the information
in all the label file formats.

Implement readers/writers for a variety of label file formats.
Ideally these will target/draw from the meta label standard.

Formalize the mapping between various elements of the different label
file formats.

=head1 VERSION

SoundLabel 0.3 (01/10/2008)

=head1 AUTHOR

SoundLabel was written and is maintained by Ronald Sprouse
(ronald**atsign**berkeley.edu).

Please email me with bug reports, comments, suggestions, etc.

=head1 COPYRIGHT

Copyright 2008, Ronald Sprouse. All rights reserved.

=head1 DISCLAIMER

This package is distributed in the hope that it will be useful
for other speech researchers. However, this package is distributed
WITHOUT ANY WARRANTY that it will be useful for any specific
purpose or that it will not harm the user's data. This package
must be used at the user's own discretion, and the author shall
not be held accountable for any results from the use of this
package.

=cut

