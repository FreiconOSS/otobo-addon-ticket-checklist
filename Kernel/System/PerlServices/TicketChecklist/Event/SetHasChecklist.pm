# --
# Kernel/System/PerlServices/TicketChecklist/Event/SetHasChecklist.pm - an event module to update the ticket history
# Copyright (C) 2016 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PerlServices::TicketChecklist::Event::SetHasChecklist;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::System::Log
    Kernel::System::PerlServices::TicketChecklist
    Kernel::System::DynamicField
    Kernel::System::DynamicField::Backend
);

=head1 NAME

Kernel::System::PerlServices::Event::SetHasChecklist

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
    my $Event    = $Param{Event};
    my $TicketID = $Param{Data}->{TicketID};

    return if !$TicketID;

    my $DynamicFieldName = $ConfigObject->Get('TicketChecklist::DynamicFieldHasChecklist') || 'TicketHasChecklist';
    my $DynamicField     = $DynamicFieldObject->DynamicFieldGet( Name => $DynamicFieldName );

    return if !$DynamicField;

    my $Value = $Event eq 'TicketChecklistRemove' ? 0 : 1;

    $BackendObject->ValueSet(
        DynamicFieldConfig => $DynamicField,
        ObjectID           => $TicketID,
        Value              => $Value,
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
