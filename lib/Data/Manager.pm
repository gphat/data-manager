package Data::Manager;
use Moose;
use MooseX::Storage;

with 'MooseX::Storage::Deferred';

# ABSTRACT: The Marriage of Message::Stack & Data::Verifier

use Message::Stack;
use Message::Stack::Parser::DataVerifier;

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
    my $ship_stack = $dm->messages_for_scope('shipping_address');

=begin :prelude

=head1 SERIALIZATION

The Data::Manager object may be serialized thusly:

  my $ser = $dm->freeze({ format => 'JSON' });
  # later
  my $dm = Data::Manager->thaw($ser, { format => 'JSON' });

This is possible thanks to the magic of L<MooseX::Storage>.  All attributes
B<except> C<verifiers> are stored.  B<Serialization causes the verifiers
attribute to be set to undefined, as those objects are not serializable>.

=end :prelude

=attr messages

The L<Message::Stack> object for this manager.  This attribute is lazily
populated, parsing the L<Data::Verifier::Results> objects.  After fetching
this attribute any changes to the results B<will not be reflected in the
message stack>.

=method messages_for_scope ($scope)

Returns a L<Message::Stack> object containing messages for the specified
scope.

=cut

has 'messages' => (
    is => 'ro',
    isa => 'Message::Stack',
    lazy_build => 1,
    handles => {
        'messages_for_scope' => 'for_scope',
    }
);

has '_parser' => (
    is => 'ro',
    isa => 'Message::Stack::DataVerifier',
);

=attr results

HashRef of L<Data::Verifier::Results> objects, keyed by scope.

=method get_results ($scope)

Gets the L<Data::Verifier::Results> object for the specified scope.

=method set_results ($scope, $results)

Sets the L<Data::Verifier::Results> object for the specified scope.

=cut

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

=attr verifiers

HashRef of L<Data::Verifier> objects, keyed by scope.

=cut

has 'verifiers' => (
    traits => [ 'Hash', 'DoNotSerialize' ],
    is => 'ro',
    isa => 'HashRef',
    default => sub { {} },
    handles => {
        'set_verifier' => 'set',
        'get_verifier' => 'get'
    }
);

sub _build_messages {
    my ($self) = @_;

    # We lazily build the messages to avoid parsing the results until the last
    # possible moment.  This lets the user fiddle with the results if they
    # want.

    my $stack = Message::Stack->new;
    foreach my $scope (keys %{ $self->results }) {
        my $results = $self->get_results($scope);
        Message::Stack::Parser::DataVerifier->parse($stack, $scope, $results);
    }

    return $stack;
}

=method success

Convenience method that checks C<success> on each of the results in this
manager.  Returns false if any are false.

=cut

sub success {
    my ($self) = @_;

    foreach my $res (keys %{ $self->results }) {
        return 0 unless $self->get_results($res)->success;
    }

    return 1;
}

=method verify ($scope, $data);

Verify the data against the specified scope.  After verification the results
and messages will be automatically created and stored.  The
L<Data::Verifier::Results> class will be returned.

=cut

sub verify {
    my ($self, $scope, $data) = @_;

    my $verifier = $self->get_verifier($scope);
    die("No verifier for scope: $scope") unless defined($verifier);

    my $results = $verifier->verify($data);
    $self->set_results($scope, $results);

    return $results;
}

=begin :postlude

=head1 ACKNOWLEDGEMENTS

Justin Hunter

Jay Shirley

Brian Cassidy

=end :postlude

=cut

__PACKAGE__->meta->make_immutable;
no Moose;

1;