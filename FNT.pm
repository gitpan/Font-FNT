package Font::FNT;

our $VERSION = '0.01';

use strict;
use warnings;
use YAML();

my @Spec = qw
(
 n   Version
 L   Size
 Z60 Copyright
 S   Type
 S   Points
 S   VertRes
 S   HorizRes
 S   Ascent
 S   InternalLeading
 S   ExternalLeading
 C   Italic
 C   Underline
 C   StrikeOut
 S   Weight
 C   CharSet
 S   PixWidth
 S   PixHeight
 C   PitchAndFamily
 S   AvgWidth
 S   MaxWidth
 C   FirstChar
 C   LastChar
 C   DefaultChar
 C   BreakChar
 S   WidthBytes
 L   Device
 L   Face
 L   BitsPointer
 L   BitsOffset
 Z1  Reserved
 L   Flags
 S   Aspace
 S   Bspace
 S   Cspace
 L   ColorPointer
 Z16 Reserved1
);
my ( @k, @v );
for ( my $i = 0; $i < @Spec; $i += 2 )
{
  push @k, $Spec[$i+1];
  push @v, $Spec[$i+0];
}
# -----------------------------------------------------------------------------
sub load
# -----------------------------------------------------------------------------
{
  my $class = shift;
  my $File  = shift;
  my $self  = {};

  open my $f, $File or die $!;
  binmode $f;
  local $/;
  my $s = <$f>;
  my @a = unpack "@v A*", $s;
  my $Rest = pop @a;
  @$self{@k} = @a;

  $self->{FaceName} = unpack "x$self->{Face} Z*", $s;
  my $CharTableSize = $self->{LastChar} - $self->{FirstChar} + 2;
  my @CharTable = unpack 'SL' x $CharTableSize, $Rest;
  for ( 0 .. $CharTableSize - 2 )
  {
    my $Width  = $CharTable[2*$_];
    my $Offset = $CharTable[2*$_+1];
    my $Bytes  = $CharTable[2*$_+3] - $Offset;
    my $Char   = { Width => $Width, Code => $_ + $self->{FirstChar} };
    $self->{Chars}[$_] = $Char;
    my @Bmp = unpack "x$Offset C$Bytes", $s;
    my @Cmp;
    $Cmp[$_ % $self->{PixHeight}] .= sprintf '%08b', $Bmp[$_] for 0 .. $#Bmp;
    $_ = substr $_, 0, $Width for @Cmp;
    tr/01/-#/ for @Cmp;
    $Char->{BitMap} = \@Cmp;
  }
  bless $self, $class;
}
# -----------------------------------------------------------------------------
sub save
# -----------------------------------------------------------------------------
{
  my $self = shift;
  my $File = shift;

  my @CharTable;
  my $CharTableSize = $self->{LastChar} - $self->{FirstChar} + 2;
  my $BitsOffset    = 148 + $CharTableSize * 6;
  my $Offset        = $BitsOffset;
  my $Bits          = '';
  my $Sentinel      =
  {
    Width  =>          $self->{AvgWidth}
  , BitMap => [ ('-' x $self->{AvgWidth} ) x $self->{PixHeight} ]
  };
  for ( @{$self->{Chars}}, $Sentinel )
  {
    my @Bmp = @{$_->{BitMap}};
    tr/-#/01/ for @Bmp;
    my $Bmp;
    for ( my $Offset = 0; $Offset < $_->{Width}; $Offset += 8 )
    {
      $Bmp .= pack 'B8', substr $_, $Offset for @Bmp;
    }
    push @CharTable, $_->{Width};
    push @CharTable, $Offset;
    $Offset += length $Bmp;
    $Bits .= $Bmp;
  }
  $self->{BitsOffset} = $BitsOffset;
  $self->{Face}       = $Offset;
  $self->{Size}       = $Offset + length( $self->{FaceName} ) + 1;

  my $s  = pack "@v", @$self{@k};
     $s .= pack 'SL' x $CharTableSize, @CharTable;
     $s .= $Bits;
     $s .= pack 'Z*', $self->{FaceName};

  open my $f, ">$File" or die $!;
  binmode $f;
  print $f $s;
}
# -----------------------------------------------------------------------------
sub save_yaml
# -----------------------------------------------------------------------------
{
  my $self = shift;
  my $File = shift;

  local $YAML::Indent = 1;

  YAML::DumpFile( $File, $self );
}
# -----------------------------------------------------------------------------
sub load_yaml
# -----------------------------------------------------------------------------
{
  my $class = shift;
  my $File  = shift;

  my $self  = YAML::LoadFile( $File );

  bless $self, $class;
}
# -----------------------------------------------------------------------------
sub save_pbm
# -----------------------------------------------------------------------------
{
  my $self = shift;
  my $File = shift;

  open my $f,'>', $File or die "Failed to open `$File': $!";

  my $Width = 0;
     $Width += length $_->{BitMap}[0] for @{$self->{Chars}};
  local $\ = "\n";
  print $f 'P1';
  print $f $Width;
  print $f $self->{PixHeight};
  local $\ = '';

  for my $y ( 0 .. $self->{PixHeight} - 1 )
  {
    for ( @{$self->{Chars}} )
    {
      my $s = $_->{BitMap}[$y];
      $s =~ tr/-#/01/;;
      print $f $s;
    }
    print $f "\n";
  }
}
# -----------------------------------------------------------------------------
1;

=head1 NAME

Font::FNT - Load, manipulate and save Windows raster fonts

=head1 SYNOPSIS

  use Font::FNT();


  my $fnt = Font::FNT->load('test.fnt');

  $fnt->save_yaml('test.yml');


  # scite test.yml


  $fnt = Font::FNT->load_yaml('test.yml');

  $fnt->save_pbm('test.pbm');


  $fnt->save('test.fnt');

=head1 DESCRIPTION

This module provides basic load, manipulate and save functionality for
Windows 3.00 raster fonts (.FNT files).

=head2 Methods

=over

=item load( $filename )

Loads a .FNT file. This is a constructor method and returns an
Font::FNT instance.

=item save_yaml( $filename )

Saves a Font::FNT instance into a notepadable format (YAML).
You can use your prefered text editor to manipulate that serialized
Font::FNT instance.

=item load_yaml( $filename )

Loads a YAML file (which should contain a serialized Font::FNT instance).
This is a constructor method and returns an Font::FNT instance.

=item save_pbm( $filename )

Saves a Font::FNT instance as portable bitmap (pbm) file.
Yo can use this for preview purposes.

=item save( $filename )

Saves a Font::FNT instance as .FNT file.

=back

=head1 AUTHOR

Steffen Goeldner <sgoeldner@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2004 Steffen Goeldner. All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<perl>, L<YAML>, L<Image::Pbm>.

=cut
