package Pod::Weaver::Section::SeeAlso;

# ABSTRACT: add a SEE ALSO pod section

use Moose 1.01;
use Moose::Autobox 0.10;

use Pod::Weaver::Role::Section 3.100710;
with 'Pod::Weaver::Role::Section';

sub weave_section {
	my ($self, $document, $input) = @_;
	my $zilla = $input->{zilla} or return;

	# find the main module's name
	my $main = $zilla->main_module->name;
	my $is_main = $main eq $input->{filename} ? 1 : 0;
	$main =~ s|^lib/||;
	$main =~ s/\.pm$//;
	$main =~ s|/|::|g;

	# Is the SEE ALSO section already in the POD?
	my $see_also;
	foreach my $i ( 0 .. $#{ $input->{pod_document}->children } ) {
		my $para = $input->{pod_document}->children->[$i];
		next unless $para->isa('Pod::Elemental::Element::Nested')
			and $para->command eq 'head1'
			and $para->content eq 'SEE ALSO';

		$see_also = $para;
		splice( @{ $input->{pod_document}->children }, $i, 1 );
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
					if ( $l !~ /^L\<.+\>$/ ) {
						die 'Unknown POD in SEE ALSO: ' . $l;
					} else {
						push( @links, $l );
					}
				}
			} else {
				die 'Unknown POD in SEE ALSO: ' . ref( $child );
			}
		}
	}
	if ( ! $is_main ) {
		unshift( @links, "L<$main>" );
	}

	if ( @links ) {
		$document->children->push(
			Pod::Elemental::Element::Nested->new( {
				command => 'head1',
				content => 'SEE ALSO',
				children => [
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
	my( $title, $contents ) = @_;

	my $str = $title;
	if ( defined $contents ) {
		$str .= "\n\n$contents";
	}

	return Pod::Elemental::Element::Nested->new( {
		command => 'item',
		content => '*',
		children => [
			Pod::Elemental::Element::Pod5::Ordinary->new( {
				content => $str,
			} ),
		],
	} );
}

1;

=pod

=head1 DESCRIPTION

This section plugin will produce a hunk of pod that references the main module of a dist
from it's submodules and adds any other text already present in the pod.

In the main module, this section plugin just transforms the links into a proper list. In the
submodules, it also adds the link to the main module.

WARNING: Please do not put any other POD commands in your SEE ALSO section!

What you should do when you want to add extra links is:

	=head1 SEE ALSO
	L<Foo::Bar>
	L<Bar::Baz>

And this module will automatically convert it into:

	=head1 SEE ALSO
	=over 4
	=item *
	L<Main::Module>
	=item *
	L<Foo::Bar>
	=item *
	L<Bar::Baz>
	=back

=cut

