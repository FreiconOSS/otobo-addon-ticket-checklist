# --
# Copyright (C) 2021 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Preferences::ChecklistNotifications;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::System::DB
    Kernel::System::Web::Request
    Kernel::Output::HTML::Layout
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{Notifications} = [qw/
        ItemDelete
        ItemResponsibleUpdate
        ItemStatusUpdate
        ItemDueDateBefore
        ItemDueDateUpdate
        ItemDateStartBefore
        ItemDateStartUpdate
        ItemsAllClosed
        ItemChangeNote
    /];

    return $Self;
}

sub Param {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $JSONObject   = $Kernel::OM->Get('Kernel::System::JSON');

    my @Params;

    # get the user preferences (this needs to be done only once)
    my $UserNotifications = $JSONObject->Decode(
        Data => $Param{UserData}->{ChecklistNotifications} // '{}',
    );

    my $AllChecked;
    if ( !%{ $UserNotifications || {} } ) {
        $AllChecked = 1;
    }

    for my $Notification ( @{ $Self->{Notifications} || [] } ) {
        my $Checked = $UserNotifications->{$Notification};

        $LayoutObject->Block(
            Name => 'ChecklistNotification',
            Data => {
                Notification     => $Notification,
                NotificationName => $Notification,
                Checked          => $AllChecked || $Checked,
            },
        );
    }

    # generate HTML
    my $Output = $LayoutObject->Output(
        TemplateFile => 'PreferencesChecklistNotifications',
        Data         => \%Param,
    );

    push(
        @Params,
        {
            %Param,
            Block => 'RawHTML',
            HTML  => $Output,
            Name  => 'ChecklistNotifications'
        },
    );

    return @Params;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $UserObject  = $Kernel::OM->Get('Kernel::System::User');
    my $JSONObject  = $Kernel::OM->Get('Kernel::System::JSON');
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    my %ChecklistNotifications;

    my @Notifications = @{ $Self->{Notifications} || [] };
    for my $Notification ( @Notifications ) {
        my $Enabled = $ParamObject->GetParam( Param => $Notification ) || 0;

        $ChecklistNotifications{$Notification} = $Enabled;
    }

    my $Value = $JSONObject->Encode(
        Data => \%ChecklistNotifications
    );

    $UserObject->SetPreferences(
        UserID => $Param{UserData}->{UserID},
        Key    => 'ChecklistNotifications',
        Value  => $Value // '',
    );

    $Self->{Message} = 'Preferences updated successfully!';
    return 1;
}

sub Error {
    my ( $Self, %Param ) = @_;

    return $Self->{Error} || '';
}

sub Message {
    my ( $Self, %Param ) = @_;

    return $Self->{Message} || '';
}

1;
