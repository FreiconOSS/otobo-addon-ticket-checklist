# --
# Kernel/System/Ticket/Event/SetTicketChecklists.pm - Set ticket checklist when ticket is created via webinterface
# Copyright (C) 2015 - 2022 Perl-Services.de, https://www.perl-services.de
# Copyright (C) 2026 Freicon GmbH & Co. KG, https://freicon.de/
# --
# Modified by Freicon GmbH & Co. KG, 2026-10-26: ported to OTOBO 11.
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::SetTicketChecklists;

use strict;
use warnings;

use List::Util qw(first);

our @ObjectDependencies = qw(
    Kernel::System::Log
    Kernel::System::DateTime
    Kernel::System::DynamicField
    Kernel::System::DynamicField::Backend
    Kernel::System::PerlServices::TicketChecklistTemplate
    Kernel::System::PerlServices::TicketChecklist
    Kernel::System::Cache
    Kernel::System::Web::Request
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

    my $LogObject          = $Kernel::OM->Get('Kernel::System::Log');
    my $CacheObject        = $Kernel::OM->Get('Kernel::System::Cache');
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $BackendObject      = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    for my $Needed (qw(Data Event Config UserID)) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );

            return;
        }
    }

    for my $NeededData (qw(TicketID)) {
        if ( !$Param{Data}->{$NeededData} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $NeededData in Data!",
            );

            return;
        }
    }

    my $FormID = $ParamObject->GetParam( Param => 'FormID' );

    if ( !$FormID ) {
        if ( $ConfigObject->Get('TicketChecklist::Debug') ) {
            $LogObject->Log(
                Priority => 'notice',
                Message  => "No FormID found - most probably due to the fact that the ticket was created via mail!",
            );
        }

        return;
    }

    # get TemplateID from Cache
    my $TemplateID = $CacheObject->Get(
        Type  => 'TicketChecklistID',
        Key   => $FormID,
    );

    my $Checklist = $CacheObject->Get(
        Type  => 'TicketChecklist',
        Key   => $FormID,
    );

    return if !$TemplateID && !$Checklist;

    if ( $TemplateID ) {
        my $FieldName = 'TicketChecklistTemplates';
        my $Field     = $DynamicFieldObject->DynamicFieldGet( Name => $FieldName );

        $BackendObject->ValueSet(
            DynamicFieldConfig => $Field,
            ObjectID           => $Param{Data}->{TicketID},
            Value              => $TemplateID,
            UserID             => $Param{UserID},
        );
    }

    if ( $Checklist ) {
        return $Self->_AddChecklist( %Param, Checklist => $Checklist );
    }
    elsif ( $TemplateID ) {
        return $Self->_FromTemplate( %Param, TemplateID => $TemplateID );
    }
}

sub _AddChecklist {
    my ($Self, %Param) = @_;

    my $ChecklistObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');
    my $JSONObject      = $Kernel::OM->Get('Kernel::System::JSON');

    my $ItemsRef  = $JSONObject->Decode( Data => $Param{Checklist} || '[]' );
    my @Checklist = @{ $ItemsRef };

    $ChecklistObject->TicketChecklistCreate(
        TicketID  => $Param{Data}->{TicketID},
        UserID    => $Param{UserID},
    );

    my $Position = 1;
    for my $Item ( @Checklist ) {
        my $StatusID   = delete $Item->{Status};
        my $PriorityID = delete $Item->{Priority};

        $ChecklistObject->TicketChecklistAdd(
            %{$Item},
            StatusID    => $StatusID,
            PriorityID  => $PriorityID,
            Position    => $Position++,
            TicketID    => $Param{Data}->{TicketID},
            UserID      => $Param{UserID},
        );
    }

    return 1;
}

sub _FromTemplate {
    my ($Self, %Param) = @_;

    my $TemplateObject  = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistTemplate');
    my $ChecklistObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');

    my $TemplateID = $Param{TemplateID};

    # get template
    my %Template = $TemplateObject->TemplateGet(
        ID => $TemplateID,
    );

    return 1 if !%Template || !$Template{Items};

    $ChecklistObject->TicketChecklistCreate(
        TicketID  => $Param{Data}->{TicketID},
        UserID    => $Param{UserID},
    );

    # save items
    my $PosCounter = 1;
    for my $Item ( @{ $Template{Items} } ) {
        my $DueDate;

        if ( $Item->{DueDateDiff} ) {
            my $DateTimeObject = $Kernel::OM->Create('Kernel::System::DateTime');
            $DateTimeObject->Add( Seconds => $Item->{DueDateDiff} * 60 );
            $DueDate = $DateTimeObject->ToString();
        }

        my $DateStart;

        if ( $Item->{DateStartDiff} ) {
            my $DateTimeObject = $Kernel::OM->Create('Kernel::System::DateTime');
            $DateTimeObject->Add( Seconds => $Item->{DateStartDiff} * 60 );
            $DateStart = $DateTimeObject->ToString();
        }

        my $StatusID = delete $Item->{Status};

        $ChecklistObject->TicketChecklistAdd(
            %{$Item},
            StatusID      => $StatusID,
            Position      => $PosCounter,
            PriorityID    => $Item->{Priority},
            ResponsibleID => $Item->{Responsible} || $Param{UserID} || 1,
            DueDate       => $DueDate,
            DateStart     => $DateStart,
            TicketID      => $Param{Data}->{TicketID},
            UserID        => $Param{UserID},
        );

        $PosCounter++;
    }

    return 1;
}

1;
