# --
# Kernel/Modules/AgentTicketChecklistTemplates.pm 
# Copyright (C) 2017 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentTicketChecklistTemplates;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::Output::HTML::Layout
    Kernel::System::Web::Request
    Kernel::System::Group
    Kernel::System::PerlServices::TicketChecklistTemplate
);

use Kernel::Language qw(Translatable);
use Kernel::System::VariableCheck qw(:all);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $TemplateObject     = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistTemplate');
    my $GroupObject        = $Kernel::OM->Get('Kernel::System::Group');

    my $Output;

    if ( $Self->{Subaction} eq 'UpdateTemplateList' ) {
        my $CustomerID = $ParamObject->GetParam( Param => 'CustomerID' );

        my @UserGroups = $GroupObject->GroupMemberList(
            UserID => $Self->{UserID},
            Result => 'ID',
            Type   => 'rw',
        );

        my %TemplateList = $TemplateObject->TemplateList(
            GroupIDs    => [ @UserGroups ],
            Valid       => 1,
            CustomerIDs => [ $CustomerID ],
        );

        my $JSON = $LayoutObject->BuildSelectionJSON(
            [
                {
                    Name         => 'TicketChecklistID',
                    Data         => \%TemplateList,
                    Translation  => 0,
                    PossibleNone => 1,
                },
            ],
        );

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSON,
            Type        => 'inline',
            NoCache     => 1,
        );
    }
}


1;
