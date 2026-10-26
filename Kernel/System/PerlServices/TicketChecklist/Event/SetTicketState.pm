# --
# Copyright (C) 2017 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PerlServices::TicketChecklist::Event::SetTicketState;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::System::PerlServices::TicketChecklist
    Kernel::System::PerlServices::TicketChecklistStatus
    Kernel::System::Ticket
    Kernel::System::Log
    Kernel::Config
);

=head1 NAME

Kernel::System::PerlServices::Event::SetTicketState - TicketChecklist notification lib

=head1 SYNOPSIS

Event handler module to set ticket state when checklist item state is changed

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
    my $ChecklistObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');
    my $StatusObject    = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistStatus');
    my $TicketObject    = $Kernel::OM->Get('Kernel::System::Ticket');
    my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');

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

    return 1 if $Param{Event} ne 'ItemStatusUpdate';
    return 1 if !$ConfigObject->Get('TicketChecklist::AllowTicketsAsItems');

    # do not modify the original event, because we need this unmodified in later event modules
    my $Event = $Param{Event};

    my %Item = $ChecklistObject->TicketChecklistGet(
        ID => $Param{Data}->{ItemID} // -1,
    );

    return 1 if !%Item;
    return 1 if $Item{Title} !~ m{\A[#]}xms;
    return 1 if !$Item{ForeignTicketID};

    my $Mapping = $ConfigObject->Get('TicketChecklist::ItemStateToTicketState');

    return 1 if !$Mapping;
    return 1 if !$Mapping->{ $Item{Status} };

    $TicketObject->TicketStateSet(
        State    => $Mapping->{ $Item{Status} },
        TicketID => $Item{ForeignTicketID},
        UserID   => $Param{UserID},
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
