package Data::Manager;
use Moose;

use Message::Stack;
use Message::Stack::DataVerifier;

our $VERSION = '0.01';

has 'messages' => (
    is => 'ro',
    isa => 'Message::Stack',
    default => sub { Message::Stack->new },
    lazy => 1,
    handles => {
        'messages_for_scope' => 'for_scope',
    }
);

has '_parser' => (
    is => 'ro',
    isa => 'Message::Stack::DataVerifier',
);

has 'results' => (
    traits => [ 'Hash' ],
    is => 'ro',
    isa => 'HashRef',
    default => sub { {} },
    handles => {
        'set_results' => 'set',
        'get_results' => 'get'
    }
);

has 'verifiers' => (
    traits => [ 'Hash' ],
    is => 'ro',
    isa => 'HashRef',
    default => sub { {} },
    handles => {
        'set_verifier' => 'set',
        'get_verifier' => 'get'
    }
);

sub verify {
    my ($self, $scope, $data) = @_;

    my $verifier = $self->get_verifier($scope);
    die("No verifier for scope: $scope") unless defined($verifier);

    my $results = $verifier->verify($data);
    $self->set_results($scope, $results);

    Message::Stack::DataVerifier->parse($self->messages, $scope, $results);

    return $results;
}

1;

__END__

=head1 NAME

Data::Manager - The Marriage of Message::Stack & Data::Verifier

=head1 DESCRIPTION

Data::Manager provides a convenient mechanism for managing multiple
L<Data::Verifier> inputs with a single L<Message::Stack>, as well as
convenient retrieval of the results of verification.

This module is useful if you have complex forms and you'd prefer to create
separate L<Data::Verifier> objects, but want to avoid creating a complex
hashref of your own creation to manage things.

It should also be noted that if married with L<MooseX::Storage>, this entire
object and it's contents can be serialized.  This maybe be useful with
L<Catalyst>'s C<flash> for storing the results of verification between
redirects.

=head1 SYNOPSIS

    use Data::Manager;
    use Data::Verifier;

    my $dm = Data::Manager->new;

    # Create a verifier for the 'billing_address'
    my $verifier = Data::Verifier->new(
        profile => {
            address1 => {
                required=> 1,
                type    => 'Str'
            }
            # ... more fields
        }
    );
    $dm->set_verifier('billing_address', $verifier);

    # Addresses are the same, reuse the verifier
    $dm->set_verifier('shipping_address', $verifier);

    my $ship_data = {
        address1 => { '123 Test Street' },
        # ... more
    };
    my $bill_data => {
        address1 => { '123 Test Street' }
        # ... more
    };

    $dm->verify('billing_address', $bill_data);
    $dm->verify('shipping_address', $ship_data);
    
    # Later...
    
    my $bill_results = $dm->get_results('billing_address');
    my $bill_stack = $dm->messages_for_scope('billing_address');
    
    my $ship_results = $dm->get_results('shipping_address');
    my $ship_stack = $dm->messages_for_scope('shipping_address);

=head1 ATTRIBUTES

=head2 messages

The L<Message::Stack> object for this manager.

=head2 results

HashRef of L<Data::Verifier::Results> objects, keyed by scope.

=head2 verifiers

HashRef of L<Data::Verifier> objects, keyed by scope.

=head1 METHODS

=head2 messages_for_scope ($scope)

Returns a L<Message::Stack> object containing messages for the specified
scope.

=head2 verify ($scope, $data);

Verify the data against the specified scope.  After verification the results
and messages will be automatically created and stored.  The
L<Data::Verifier::Results> class will be returned.

=head1 AUTHOR

Cory G Watson, C<< <gphat at cpan.org> >>

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2009 Cory G Watson.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

