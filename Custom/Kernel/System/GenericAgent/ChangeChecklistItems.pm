# --
# Copyright (C) 2016 - 2022 Perl-Services.de, https://www.perl-services.de
# Copyright (C) 2026 Freicon GmbH & Co. KG, https://freicon.de/
# --
# Modified by Freicon GmbH & Co. KG, 2026-10-26: ported to OTOBO 11.
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::GenericAgent::ChangeChecklistItems;

use strict;
use warnings;

use List::Util qw(first);

our @ObjectDependencies = qw(
    Kernel::System::Log
    Kernel::System::PerlServices::TicketChecklist
);

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
    my $MainObject      = $Kernel::OM->Get('Kernel::System::Main');
    my $ChecklistObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');
    my $PriorityObject  = $Kernel::OM->Get('Kernel::System::Priority');
    my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');

    for my $Needed ( qw/TicketID/ ) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );

            return;
        }
    }

    # group parameters
    my %ItemChanges;
    my @ItemNameParams = grep{ $_ =~ m{\AItem_\d+} }keys %{ $Param{New} || {} };

    my $UseAutocomplete = $ConfigObject->Get('TicketChecklist::ResponsibleAutocomplete');
    my $Module          = $ConfigObject->Get('TicketChecklist::ResponsibleAutocompleteModule');

    my $ResponsibleObject = $Kernel::OM->Get('Kernel::System::User');
    my $Method            = 'UserLookup';

    if ( $UseAutocomplete ) {
        $ResponsibleObject = $Kernel::OM->Get(
            'Kernel::System::PerlServices::TicketChecklist::Autocomplete::' . $Module
        );

        $Method = 'Lookup';
    }

    for my $NameParam ( @ItemNameParams ) {
        my ($Count) = $NameParam =~ m{\AItem_ (\d+) \z}xms;

        my $Name = $Param{New}->{$NameParam};

        KEY:
        for my $Key ( qw/Status DueDate Responsible Priority/ ) {
            my $Value = $Param{New}->{ $Key . '_' . $Count };

            next KEY if !defined $Value || $Value eq '';

            $ItemChanges{$Name}->{$Key} = $Value;
        }

        if ( $ItemChanges{$Name}->{Priority} ) {
            $ItemChanges{$Name}->{PriorityID} = $PriorityObject->PriorityLookup(
                Priority => $ItemChanges{$Name}->{Priority},
            );
        }

        if ( $ItemChanges{$Name}->{Responsible} ) {
            my $ResponsibleKey = $UseAutocomplete ? 'ResponsibleKey' : 'ResponsibleID';

# TODO: only search for user if it isn't the generic responsible user
            $ItemChanges{$Name}->{$ResponsibleKey} = $ResponsibleObject->$Method(
                UserLogin => $ItemChanges{$Name}->{Responsible},
            );
        }
    }

    # update checklist items
    NAME:
    for my $Name ( sort keys %ItemChanges ) {
        my $ID = $ChecklistObject->ChecklistItemLookup(
            Name     => $Name,
            TicketID => $Param{TicketID},
        );

        next NAME if !$ID;

        my %Item = $ChecklistObject->TicketChecklistGet(
            ID => $ID,
        );

        $ChecklistObject->TicketChecklistUpdate(
            %Item,
            %{ $ItemChanges{$Name} },
            UserID => 1,
        );
    }

    return 1;
}

1;
