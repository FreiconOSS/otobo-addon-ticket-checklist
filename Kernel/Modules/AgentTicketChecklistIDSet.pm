# --
# Kernel/Modules/AgentTicketChecklistIDSet.pm - set checklist id for the new ticket
# Copyright (C) 2015 - 2022 Perl-Services.de, https://www.perl-services.de
# Copyright (C) 2026 Freicon GmbH & Co. KG, https://freicon.de/
# --
# Modified by Freicon GmbH & Co. KG, 2026-10-26: ported to OTOBO 11.
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentTicketChecklistIDSet;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::Config
    Kernel::Output::HTML::Layout
    Kernel::System::Web::Request
    Kernel::System::Cache
    Kernel::System::DateTime
    Kernel::System::PerlServices::TicketChecklistStatus
    Kernel::System::PerlServices::TicketChecklistTemplate
    Kernel::System::JSON
    Kernel::System::Log
    Kernel::System::Main
);

sub new {
    my ( $Type, %Param ) = @_;

    # create object
    my $Self = bless {%Param}, $Type;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $ParamObject    = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject   = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ConfigObject   = $Kernel::OM->Get('Kernel::Config');
    my $CacheObject    = $Kernel::OM->Get('Kernel::System::Cache');
    my $JSONObject     = $Kernel::OM->Get('Kernel::System::JSON');
    my $StatusObject   = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistStatus');
    my $TemplateObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistTemplate');
    my $LogObject      = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject     = $Kernel::OM->Get('Kernel::System::Main');

    my $DEBUG = $ConfigObject->Get('TicketChecklist::Debug');

    # get parameters from request
    my %GetParam;
    for my $ParamName (qw(ChecklistID FormID AddItemsToChecklist)) {
        $GetParam{$ParamName} = $ParamObject->GetParam( Param => $ParamName ) || '';
    }

    if ( $Self->{Subaction} && $Self->{Subaction} eq 'ReloadWidget' ) {
        my $Result = {
            Success => 1,
            HasHTML => 1,
        };

        my $ItemsJSON = $CacheObject->Get(
            Type  => 'TicketChecklist',
            Key   => $GetParam{FormID},
        );

        my $Items = $JSONObject->Decode( Data => $ItemsJSON || '[]' );

        $Result->{HTML} = $Self->_ChecklistWidget(
            Items  => $Items,
            FormID => $GetParam{FormID},
        );

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSONObject->Encode( Data => $Result ),
            Type        => 'inline',
            NoCache     => 0,
        );
    }

    my $Result = { Success => 1 };

    my $ExistingID = $CacheObject->Get(
        Type  => 'TicketChecklistID',
        Key   => $GetParam{FormID},
    );

    if ( !$GetParam{AddItemsToChecklist} ) {
        $ExistingID = '';
    }

    $ExistingID //= '';

    my @ExistingIDs = split /;/, $ExistingID;

    push @ExistingIDs, $GetParam{ChecklistID};

    $CacheObject->Set(
        Type  => 'TicketChecklistID',
        Key   => $GetParam{FormID},
        Value => join( ';', @ExistingIDs ),
        TTL   => 24 * 60 * 60, # live one hour
    );

    if ( $DEBUG ) {
        $LogObject->Log(
            Priority => 'debug',
            Message  => $MainObject->Dump( [ $ExistingID, $GetParam{ChecklistID} ] ),
        );
    }

    if ( $ConfigObject->Get('TicketChecklist::ShowChecklistInTicketCreate') ) {
        if ( !$GetParam{AddItemsToChecklist} ) {
            $CacheObject->Set(
                Type  => 'TicketChecklist',
                Key   => $GetParam{FormID},
                Value => '',
                TTL   => 24 * 60 * 60, # live one hour
            );
        }

        $Result->{HasHTML} = 1;
        $Result->{HTML}    = '';

        if ( $GetParam{ChecklistID} ) {
            my %Template = $TemplateObject->TemplateGet( ID => $GetParam{ChecklistID} );

            for my $Item ( @{ $Template{Items} || [] } ) {
                my $DateStart;

                if ( $Item->{DateStartDiff} ) {
                    my $DateTimeObject = $Kernel::OM->Create('Kernel::System::DateTime');
                    $DateTimeObject->Add( Seconds => $Item->{DateStartDiff} * 60 );
                    $Item->{DateStart} = $DateTimeObject->ToString();
                }
 
                my $DueDate;

                if ( $Item->{DueDateDiff} ) {
                    my $DateTimeObject = $Kernel::OM->Create('Kernel::System::DateTime');
                    $DateTimeObject->Add( Seconds => $Item->{DueDateDiff} * 60 );
                    $Item->{DueDate} = $DateTimeObject->ToString();
                }
            }

            my $ExistingItems = $CacheObject->Get(
                Type  => 'TicketChecklist',
                Key   => $GetParam{FormID},
            );

            my @AllItems;
            if ( $ExistingItems ) {
                @AllItems = @{ $JSONObject->Decode( Data => $ExistingItems ) };
            }

            push @AllItems, @{ $Template{Items} || [] };

            my $Checklist = $JSONObject->Encode( Data => \@AllItems );

            if ( $DEBUG ) {
                $LogObject->Log(
                    Priority => 'debug',
                    Message  => $MainObject->Dump( [ $ExistingItems, $Template{Items} ] ),
                );
            }

            $CacheObject->Set(
                Type  => 'TicketChecklist',
                Key   => $GetParam{FormID},
                Value => $Checklist,
                TTL   => 24 * 60 * 60, # live one hour
            );

            $Result->{HTML} = $Self->_ChecklistWidget(
                Items  => \@AllItems,
                FormID => $GetParam{FormID},
            );
        }
    }

    return $LayoutObject->Attachment(
        ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
        Content     => $JSONObject->Encode( Data => $Result ),
        Type        => 'inline',
        NoCache     => 0,
    );
}

sub _ChecklistWidget {
    my ($Self, %Param) = @_;

    my $StatusObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistStatus');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my %StatusList   = $StatusObject->TicketChecklistStatusList();
    my %StatusColors;

    $LayoutObject->Block( Name => 'SimpleView' );

    for my $StatusID ( keys %StatusList ) {
        my %StatusInfo = $StatusObject->TicketChecklistStatusGet(
            ID => $StatusID,
        );

        $StatusColors{$StatusID} = $StatusInfo{Color};
    }

    for my $Item ( @{ $Param{Items} || [] } ) {
        $Item->{StatusSelect} = $StatusList{ $Item->{Status} || $Item->{StatusID} };
        $Item->{Color}        = $StatusColors{ $Item->{Status} || $Item->{StatusID} };

        $LayoutObject->Block(
            Name => 'Item',
            Data => $Item,
        );

        $LayoutObject->Block(
            Name => 'TitlePlain',
            Data => $Item,
        );
    }

    $LayoutObject->Block(
        Name => 'ShowEditButton',
        Data => { FormID => $Param{FormID} },
    );

    my $Snippet = $LayoutObject->Output(
        TemplateFile => 'TicketChecklistWidget',
        Data         => {
            TicketFormID => $Param{FormID},
        },
    );

    return $Snippet;
}

1;
