# --
# Copyright (C) 2020 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PerlServices::TicketChecklist::Event::SetDefaultCustomerVisibility;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::System::Log
    Kernel::System::PerlServices::TicketChecklist
    Kernel::System::DynamicField
    Kernel::System::DynamicField::Backend
);

=head1 NAME

Kernel::System::PerlServices::Event::SetDefaultCustomerVisibility

=head1 SYNOPSIS

Event handler module to set customer visibility for some queues

=head1 PUBLIC INTERFACE

=over 4

=item new()

create an object

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $InfoObject   = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistTicketInfo');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # check needed stuff
    for my $Argument (qw(Data Event Config UserID)) {
        if ( !$Param{$Argument} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Argument!"
            );

            return;
        }
    }

    # do not modify the original event, because we need this unmodified in later event modules
    my $Event    = $Param{Event};
    my $TicketID = $Param{Data}->{TicketID};

    return if !$TicketID;

    my %Ticket = $TicketObject->TicketGet(
        TicketID => $TicketID,
        UserID   => $Param{UserID},
    );

    my $Queue = $Ticket{Queue};

    my %DefaultVisible = %{ $ConfigObject->Get('Queues::CustomerVisibility') || {} };

    return if !$DefaultVisible{$Queue};

    my $ID = $InfoObject->SetInfo(
        TicketID           => $TicketID,
        CustomerVisibility => 1,
        UserID             => $Param{UserID},
    );

    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
