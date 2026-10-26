# --
# Copyright (C) 2016 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PerlServices::TicketChecklist::Event::ConditionAction;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::System::Log
    Kernel::System::DB
    Kernel::System::JSON
    Kernel::System::Main
    Kernel::System::Ticket
    Kernel::System::PerlServices::TicketChecklist
);

=head1 NAME

Kernel::System::PerlServices::Event::ConditionAction

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

    my $LogObject       = $Kernel::OM->Get('Kernel::System::Log');
    my $JSONObject      = $Kernel::OM->Get('Kernel::System::JSON');
    my $MainObject      = $Kernel::OM->Get('Kernel::System::Main');
    my $DBObject        = $Kernel::OM->Get('Kernel::System::DB');
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

    return 1 if $Param{Data}->{NoConditionsActions};

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

    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $TicketID,
        DynamicFields => 1,
        UserID        => $Param{UserID},
    );

    my $Value = $Ticket{DynamicField_TicketChecklistTemplates};

    return 1 if !$Value;

    my @Templates = grep{ $_ } split /;/, $Value;

    return 1 if !@Templates;

    my $Placeholder = join ', ', ('?') x @Templates;
    my $SQL = qq~
        SELECT condition_actions
        FROM ps_checklist_template
        WHERE id IN ( $Placeholder )
    ~;

    return if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => [ map{ \$_ }@Templates ],
    );

    my @Conditions;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @Conditions, $Row[0] if $Row[0];
    }

    for my $Condition ( @Conditions ) {
        my $ConditionData = $JSONObject->Decode( Data => $Condition );

        ACTION:
        for my $Action ( @{ $ConditionData || [] } ) {
            my $ActionItems = ref $Action->{ActionItem} ? $Action->{ActionItem} : [ $Action->{ActionItem} ];
            my %AllItems    = map{ $_ => 1 }@{ $ActionItems || [] };

            my $ActionCandidate = delete $AllItems{ $Item{Title} };
            next ACTION if !$ActionCandidate;

            my $ActionStatus = $Action->{ActionStatus};

            next ACTION if !ref $ActionStatus && $ActionStatus ne $Item{StatusID};
            next ACTION if ref $ActionStatus && !grep{ $_ eq $Item{StatusID} } @{$ActionStatus};

            ITEMNAME:
            for my $ItemName ( keys %AllItems ) {
                my $ItemID = $ChecklistObject->ChecklistItemLookup(
                    Name     => $ItemName,
                    TicketID => $TicketID,
                );

                next ACTION if !$ItemID;

                my %Item = $ChecklistObject->TicketChecklistGet( ID => $ItemID );

                next ACTION if !ref $ActionStatus && $ActionStatus ne $Item{StatusID};
                next ACTION if ref $ActionStatus && !grep{ $_ eq $Item{StatusID} } @{$ActionStatus};
            }

            my $Module = $Action->{ActionModule};

            $MainObject->Require( $Module );
            my $Object = $Module->new;

            my %Params = map{ @{ $_ } }@{ $Action->{ActionParams} };

            $Object->Run(
                UserID   => $Param{UserID},
                TicketID => $TicketID,
                ItemID   => $Item{ID},
                Params   => \%Params,
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
