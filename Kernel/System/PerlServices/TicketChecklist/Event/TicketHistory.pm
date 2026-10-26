# --
# Kernel/System/PerlServices/TicketChecklist/Event/TicketHistory.pm - an event module to update the ticket history
# Copyright (C) 2015 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PerlServices::TicketChecklist::Event::TicketHistory;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::System::Log
    Kernel::System::PerlServices::TicketChecklist
    Kernel::System::Ticket
);

=head1 NAME

Kernel::System::PerlServices::Event::TicketHistory - TicketChecklist notification lib

=head1 SYNOPSIS

Event handler module to update ticket history on ticket checklist events

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

    my $LogObject       = $Kernel::OM->Get('Kernel::System::Log');
    my $TicketObject    = $Kernel::OM->Get('Kernel::System::Ticket');
    my $ChecklistObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');

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
    my $Event = $Param{Event};

    my %Item = %{ $Param{Data}->{Item} || {} };

    if ( !%Item ) {
        %Item = $ChecklistObject->TicketChecklistGet(
            ID => $Param{Data}->{ItemID},
        );
    }

    my %Comments = (
        ItemDelete            => ( join '%%', '', $Item{ID}, $Item{Title} ),
        ItemAdd               => ( join '%%', '', $Item{ID}, $Item{Title} ),
        ItemResponsibleUpdate => ( join '%%', '', $Item{ID}, $Item{Title}, $Item{Responsible} || '' ),
        ItemDueDateUpdate     => ( join '%%', '', $Item{ID}, $Item{Title}, $Item{DueDate} || '' ),
        ItemStatusUpdate      => ( join '%%', '', $Item{ID}, $Item{Title}, $Param{Data}->{OldStatus} || '', $Item{Status}  || '' ),
        ItemMove              => ( join '%%', '', $Item{ID}, $Item{Title}, $Item{TicketID} || '' ),
    );

    my $Comment = $Comments{$Event} || $Event;

    $TicketObject->HistoryAdd(
        TicketID     => $Param{Data}->{OldTicketID} || $Item{TicketID},
        Name         => $Comment,
        HistoryType  => 'TicketChecklist' . $Event,
        CreateUserID => $Param{UserID},
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
