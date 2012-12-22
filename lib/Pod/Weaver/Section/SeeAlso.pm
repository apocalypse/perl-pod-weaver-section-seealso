package Pod::Weaver::Section::SeeAlso;

# ABSTRACT: add a SEE ALSO pod section

use Moose 1.03;
use Moose::Autobox 0.10;

with 'Pod::Weaver::Role::Section' => { -version => '3.100710' };

sub mvp_multivalue_args { qw( links ) }

=attr add_main_link

A boolean value controlling whether the link back to the main module should be
added in the submodules.

Defaults to true.

=cut

has add_main_link => (
	is => 'ro',
	isa => 'Bool',
	default => 1,
);

=attr header

Specify the content to be displayed before the list of links is shown.

The default is a sufficient explanation (see L</SEE ALSO>).

=cut

has header => (
	is => 'ro',
	isa => 'Str',
	default => <<'EOPOD',
Please see those modules/websites for more information related to this module.
EOPOD

);

=attr links

Specify a list of links you want to add to the SEE ALSO section.

You can either specify it like this: "Foo::Bar" or do it in POD format: "L<Foo::Bar>". This
module will automatically add the proper POD formatting if it is missing.

The default is an empty list.

=cut

has links => (
	is => 'ro',
	isa => 'ArrayRef[Str]',
	default => sub { [ ] },
);

sub weave_section {
	## no critic ( ProhibitAccessOfPrivateData )
	my ($self, $document, $input) = @_;

	my $zilla = $input->{'zilla'} or die 'Please use Dist::Zilla with this module!';

	# find the main module's name
	my $main = $zilla->main_module->name;
	my $is_main = $main eq $input->{'filename'} ? 1 : 0;
	$main =~ s|^lib/||;
	$main =~ s/\.pm$//;
	$main =~ s|/|::|g;

	# Is the SEE ALSO section already in the POD?
	my $see_also;
	foreach my $i ( 0 .. $#{ $input->{'pod_document'}->children } ) {
		my $para = $input->{'pod_document'}->children->[$i];
		next unless $para->isa('Pod::Elemental::Element::Nested')
			and $para->command eq 'head1'
			and $para->content =~ /^SEE\s+ALSO/s;	# catches both "head1 SEE ALSO\n\nL<baz>" and "head1 SEE ALSO\nL<baz>" format

		$see_also = $para;
		splice( @{ $input->{'pod_document'}->children }, $i, 1 );
		last;
	}

	my @links;
	if ( defined $see_also ) {
		# Transform it into a proper list
		foreach my $child ( @{ $see_also->children } ) {
			if ( $child->isa( 'Pod::Elemental::Element::Pod5::Ordinary' ) ) {
				foreach my $l ( split /\n/, $child->content ) {
					chomp $l;
					next if ! length $l;
					push( @links, $l );
				}
			} else {
				die 'Unknown POD in SEE ALSO: ' . ref( $child );
			}
		}

		# Sometimes the links are in the content!
		if ( $see_also->content =~ /^SEE\s+ALSO\s+(.+)$/s ) {
			foreach my $l ( split /\n/, $1 ) {
				chomp $l;
				next if ! length $l;
				push( @links, $l );
			}
		}
	}
	if ( $self->add_main_link and ! $is_main ) {
		unshift( @links, $main );
	}

	# Add links specified in the document
	# Code copied from Pod::Weaver::Section::Name, thanks RJBS!
	# TODO how do we pick up multiple times?
	# see code here for multiple comment logic - http://cpansearch.perl.org/src/XENO/Dist-Zilla-Plugin-OurPkgVersion-0.1.4/lib/Dist/Zilla/Plugin/OurPkgVersion.pm
	my ($extralinks) = $input->{'ppi_document'}->serialize =~ /^\s*#+\s*SEEALSO:\s*(.+)$/m;
	if ( defined $extralinks and length $extralinks ) {
		# get the list!
		my @data = split( /\,/, $extralinks );
		$_ =~ s/^\s+//g for @data;
		$_ =~ s/\s+$//g for @data;
		push( @links, $_ ) for @data;
	}

	# Add extra links
	push( @links, $_ ) for @{ $self->links };

	if ( @links ) {
		$document->children->push(
			Pod::Elemental::Element::Nested->new( {
				command => 'head1',
				content => 'SEE ALSO',
				children => [
					Pod::Elemental::Element::Pod5::Ordinary->new( {
						content => $self->header,
					} ),
					# I could have used the list transformer but rjbs said it's more sane to generate it myself :)
					Pod::Elemental::Element::Nested->new( {
						command => 'over',
						content => '4',
						children => [
							( map { _make_item( $_ ) } @links ),
							Pod::Elemental::Element::Pod5::Command->new( {
								command => 'back',
								content => '',
							} ),
						],
					} ),
				],
			} ),
		);
	}
}

sub _make_item {
	my( $link ) = @_;

	# Is it proper POD?
	if ( $link !~ /^L\<.+\>$/ ) {
		# include the link text so we satisfy Perl::Critic::Policy::Documentation::RequirePodLinksIncludeText
		$link = 'L<' . $link . '|' . $link . '>';
	}

	return Pod::Elemental::Element::Nested->new( {
		command => 'item',
		content => '*',
		children => [
			Pod::Elemental::Element::Pod5::Ordinary->new( {
				content => $link,
			} ),
		],
	} );
}

1;

=pod

=for stopwords dist dzil

=for Pod::Coverage weave_section mvp_multivalue_args

=head1 DESCRIPTION

This section plugin will produce a hunk of pod that references the main module of a dist
from its submodules, and adds any other text already present in the POD. It will do this
only if it is being built with L<Dist::Zilla>, because it needs the data from the dzil object.

In the main module, this section plugin just transforms the links into a proper list. In the
submodules, it also adds the link to the main module.

For an example of what the hunk looks like, look at the L</SEE ALSO> section in this POD :)

WARNING: Please do not put any POD commands in your SEE ALSO section!

What you should do when you want to add extra links is:

	=head1 SEE ALSO
	Foo::Bar
	Bar::Baz
	www.cpan.org

And this module will automatically convert it into:

	=head1 SEE ALSO
	=over 4
	=item *
	L<Main::Module>
	=item *
	L<Foo::Bar>
	=item *
	L<Bar::Baz>
	=item *
	L<www.cpan.org>
	=back

You can specify more links by using the "links" attribute, or by specifying it as a comment. The
format of the comment is:

	# SEEALSO: Foo::Bar, Module::Nice::Foo, www.foo.com

At this time you can only use one comment line. If you need to do it multiple times, please prod me
to update the module or give me a patch :)

The way the links are ordered is: POD in the module, links attribute, comment links.

=head1 SEE ALSO
Pod::Weaver
Dist::Zilla

=cut
