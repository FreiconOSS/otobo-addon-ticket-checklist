# --
# Kernel/System/PerlServices/TicketChecklist/Event/SetHasOpenTodos.pm - an event module to update the ticket history
# Copyright (C) 2016 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PerlServices::TicketChecklist::Event::SetHasOpenTodos;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::System::Log
    Kernel::System::PerlServices::TicketChecklist
    Kernel::System::DynamicField
    Kernel::System::DynamicField::Backend
);

=head1 NAME

Kernel::System::PerlServices::Event::SetHasOpenTodos

=head1 SYNOPSIS

Event handler module to update a ticket dynamic field that tracks if there are open todos for the ticket

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

    my $LogObject          = $Kernel::OM->Get('Kernel::System::Log');
    my $ChecklistObject    = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $BackendObject      = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');

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

    if ( !%Item && $Param{Data}->{ItemID} ) {
        %Item = $ChecklistObject->TicketChecklistGet(
            ID => $Param{Data}->{ItemID},
        );
    }

    my $TicketID = $Param{Data}->{TicketID};
    if ( !$TicketID && $Item{ID} ) {
        $TicketID = $ChecklistObject->_TicketIDLookup( ID => $Item{ID} );
    }

    return if !$TicketID;

    my $DynamicFieldName = $ConfigObject->Get('TicketChecklist::DynamicFieldHasOpenTodos') || 'TicketHasOpenTodos';
    my $DynamicField     = $DynamicFieldObject->DynamicFieldGet( Name => $DynamicFieldName );

    return if !$DynamicField;

    if ( grep{ $Event eq $_ }qw/ItemsAllClosed TicketChecklistRemove/ ) {
        $BackendObject->ValueSet(
            DynamicFieldConfig => $DynamicField,
            ObjectID           => $TicketID,
            Value              => 0,
            UserID             => $Param{UserID},
        );
    }
    elsif ( grep{ $Event eq $_ }qw/TicketChecklistCreate/ ) {
        $BackendObject->ValueSet(
            DynamicFieldConfig => $DynamicField,
            ObjectID           => $TicketID,
            Value              => 1,
            UserID             => $Param{UserID},
        );
    }
    elsif ( grep{ $Event eq $_ }qw/ItemAdd ItemStatusUpdate/ ) {
        my @OpenStates = @{ $ConfigObject->Get('TicketChecklist::OpenStates') || [] };

        if ( grep{ $Item{Status} eq $_ }@OpenStates ) {
            $BackendObject->ValueSet(
                DynamicFieldConfig => $DynamicField,
                ObjectID           => $TicketID,
                Value              => 1,
                UserID             => $Param{UserID},
            );
        }
    }

    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
