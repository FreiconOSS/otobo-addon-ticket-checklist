# --
# Kernel/Modules/AgentTicketChecklistResponsibleSearch.pm - search module for responsibles
# Copyright (C) 2016 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentTicketChecklistResponsibleSearch;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::Config
    Kernel::Output::HTML::Layout
    Kernel::System::Web::Request
    Kernel::System::JSON
    Kernel::System::Log
    Kernel::System::Main
);

sub new {
    my ( $Type, %Param ) = @_;

    # create object
    my $Self = bless {%Param}, $Type;

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $ParamObject    = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject   = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ConfigObject   = $Kernel::OM->Get('Kernel::Config');
    my $JSONObject     = $Kernel::OM->Get('Kernel::System::JSON');
    my $LogObject      = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject     = $Kernel::OM->Get('Kernel::System::Main');

    my $DEBUG = $ConfigObject->Get('TicketChecklist::Debug');

    # get parameters from request
    my %GetParam;
    for my $ParamName (qw(Term)) {
        $GetParam{$ParamName} = $ParamObject->GetParam( Param => $ParamName ) || '';
    }

    my $Module = $ConfigObject->Get('TicketChecklist::ResponsibleAutocompleteModule');

    my @Result;
    if ( $Module ) {
        my $SearchObject = $Kernel::OM->Get(
            'Kernel::System::PerlServices::TicketChecklist::Autocomplete::' . $Module
        );

        my $Users = $SearchObject->ResponsibleSearch(
            Term   => $GetParam{Term},
            UserID => $Self->{UserID},
        );

        my $KeyAttribute = $SearchObject->KeyAttributeGet();

        RESPONSIBLE:
        for my $UserID ( keys %{ $Users || {} } ) {
            my $User = $Users->{$UserID};

            push @Result, {
                Label => $User->{UserFullname},
                Value => $User->{$KeyAttribute},
            };
        }
    }

    my $JSON = $LayoutObject->JSONEncode(
        Data => \@Result,
    );

    return $LayoutObject->Attachment(
        ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
        Content     => $JSON || '',
        Type        => 'inline',
        NoCache     => 1,
    );
}

1;
