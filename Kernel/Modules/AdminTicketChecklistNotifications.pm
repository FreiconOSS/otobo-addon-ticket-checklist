# --
# Kernel/Modules/AdminTicketChecklistNotifications.pm - manage ticket checklist states
# Copyright (C) 2016 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminTicketChecklistNotifications;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::Config
    Kernel::System::HTMLUtils
    Kernel::System::PerlServices::TicketChecklistNotification
    Kernel::System::Web::Request
    Kernel::Output::HTML::Layout
    Kernel::System::Valid
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $NotificationObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistNotification');
    my $ValidObject        = $Kernel::OM->Get('Kernel::System::Valid');

    my $ContentType =  $ConfigObject->Get( 'Frontend::RichText' ) ? 'text/html' : 'text/plain';

    my @Params = qw(ID Event Language Subject Text ValidID);
    my %GetParam;
    for my $Param (@Params) {
        $GetParam{$Param} = $ParamObject->GetParam( Param => $Param ) || '';
    }

    # ------------------------------------------------------------ #
    # get data 2 form
    # ------------------------------------------------------------ #
    if ( $Self->{Subaction} eq 'Edit' || $Self->{Subaction} eq 'Add' ) {
        my %Subaction = (
            Edit => 'Update',
            Add  => 'Save',
        );

        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $Self->_MaskForm(
            %GetParam,
            %Param,
            Subaction => $Subaction{ $Self->{Subaction} },
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # ------------------------------------------------------------ #
    # update action
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'Update' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        # server side validation
        my %Errors;

        if (
            !$GetParam{ValidID} ||
            !$ValidObject->ValidLookup( ValidID => $GetParam{ValidID} )
            )
        {
            $Errors{ValidIDInvalid} = 'ServerError';
        }

        for my $Param (qw(Event Language Subject Text)) {
            if ( !$GetParam{$Param} ) {
                $Errors{ $Param . 'Invalid' } = 'ServerError';
            }
        }

        my $ID = $NotificationObject->NotificationLookup(
            Event    => $GetParam{Event},
            Language => $GetParam{Language},
        );

        if ( $ID && $ID != $GetParam{ID} ) {
            $Errors{EventInvalid} = 'ServerError';
        }

        if ( %Errors ) {
            $Self->{Subaction} = 'Edit';

            my $Output = $LayoutObject->Header();
            $Output .= $LayoutObject->NavigationBar();
            $Output .= $Self->_MaskForm(
                %GetParam,
                %Param,
                %Errors,
                Subaction => 'Update',
                Submit    => 1,
            );
            $Output .= $LayoutObject->Footer();

            return $Output;
        }

        my $Update = $NotificationObject->NotificationUpdate(
            %GetParam,
            ContentType => $ContentType,
            UserID      => $Self->{UserID},
        );

        if ( !$Update ) {
            return $LayoutObject->ErrorScreen();
        }

        return $LayoutObject->Redirect( OP => "Action=AdminTicketChecklistNotifications" );
    }

    # ------------------------------------------------------------ #
    # insert state
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'Save' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        # server side validation
        my %Errors;

        if (
            !$GetParam{ValidID} ||
            !$ValidObject->ValidLookup( ValidID => $GetParam{ValidID} )
            )
        {
            $Errors{ValidIDInvalid} = 'ServerError';
        }

        for my $Param (qw(Event Language Subject Text)) {
            if ( !$GetParam{$Param} ) {
                $Errors{ $Param . 'Invalid' } = 'ServerError';
            }
        }

        my $ID = $NotificationObject->NotificationLookup(
            Event    => $GetParam{Event},
            Language => $GetParam{Language},
        );

        if ( $ID ) {
            $Errors{EventInvalid} = 'ServerError';
        }

        if ( %Errors ) {
            $Self->{Subaction} = 'Add';

            my $Output = $LayoutObject->Header();
            $Output .= $LayoutObject->NavigationBar();
            $Output .= $Self->_MaskForm(
                %GetParam,
                %Param,
                %Errors,
                Subaction => 'Save',
                Submit    => 1,
            );
            $Output .= $LayoutObject->Footer();
            return $Output;
        }

        my $Success = $NotificationObject->NotificationAdd(
            %GetParam,
            ContentType => $ContentType,
            UserID      => $Self->{UserID},
            OwnerID     => $GetParam{OwnerSelected},
        );

        if ( !$Success ) {
            return $LayoutObject->ErrorScreen();
        }

        return $LayoutObject->Redirect( OP => "Action=AdminTicketChecklistNotifications" );
    }

    elsif ( $Self->{Subaction} eq 'Delete' ) {
        $NotificationObject->NotificationDelete( %GetParam );

        return $LayoutObject->Redirect( OP => "Action=AdminTicketChecklistNotifications" );
    }

    # ------------------------------------------------------------ #
    # else ! print form
    # ------------------------------------------------------------ #
    else {
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $Self->_MaskForm();
        $Output .= $LayoutObject->Footer();

        return $Output;
    }
}

sub _MaskForm {
    my ( $Self, %Param ) = @_;

    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $NotificationObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistNotification');
    my $HTMLUtilsObject    = $Kernel::OM->Get('Kernel::System::HTMLUtils');
    my $ValidObject  = $Kernel::OM->Get('Kernel::System::Valid');

    $Self->{RichText} = $ConfigObject->Get( 'Frontend::RichText' );

    if ( !$Param{Submit} && $Param{ID} ) {
        my %Notification = $NotificationObject->NotificationGet( ID => $Param{ID} );
        for my $Key ( keys %Notification ) {
            $Param{$Key} = $Notification{$Key};
        }

        # do text/plain to text/html convert
        if ( $Self->{RichText} && $Notification{ContentType} =~ m{ text/plain }xmsi ) {
            $Param{Text} = $HTMLUtilsObject->ToHTML(
                String => $Notification{Text},
            );
        }
    
        # do text/html to text/plain convert
        elsif ( !$Self->{RichText} && $Notification{ContentType} =~ m{ text/html }xmsi ) {
            $Param{Text} = $HTMLUtilsObject->ToAscii(
                String => $Notification{Text},
            );
        }
    }

    my $ValidID = $ValidObject->ValidLookup( Valid => 'valid' );

    $Param{ValidSelect} = $LayoutObject->BuildSelection(
        Data       => { $ValidObject->ValidList() },
        Name       => 'ValidID',
        Size       => 1,
        SelectedID => $Param{ValidID} || $ValidID,
        HTMLQuote  => 1,
        Class      => 'Modernize',
    );

    # add rich etxt editor
    if ( $ConfigObject->Get( 'Frontend::RichText' ) ) {
        $LayoutObject->Block(
            Name => 'RichText',
            Data => \%Param,
        );
    }

    $Param{EventSelect} = $LayoutObject->BuildSelection(
        Data       => [qw/
            ItemChangeNote ItemDelete ItemDueDateBefore ItemStatusUpdate
            ItemResponsibleUpdate ItemsAllClosed ItemDueDateUpdate
            ItemDateStartUpdate ItemDateStartBefore
        /],
        Name       => 'Event',
        Size       => 1,
        SelectedID => $Param{Event},
        HTMLQuote  => 1,
        Class      => 'Modernize',
    );

    if ( $Self->{Subaction} ne 'Edit' && $Self->{Subaction} ne 'Add' ) {

        my %NotificationList = $NotificationObject->NotificationList();

        if ( !%NotificationList ) {
            $LayoutObject->Block(
                Name => 'NoNotificationFound',
            );
        }

        for my $NotificationID ( sort { $NotificationList{$a} cmp $NotificationList{$b} } keys %NotificationList ) {
            my %Notification = $NotificationObject->NotificationGet(
                ID => $NotificationID,
            );

            $Notification{Valid} = $ValidObject->ValidLookup( ValidID => $Notification{ValidID} // 1 );

            $LayoutObject->Block(
                Name => 'NotificationRow',
                Data => \%Notification,
            );
        }
    }

    $Param{SubactionName} = 'Update';
    $Param{SubactionName} = 'Save' if $Self->{Subaction} && $Self->{Subaction} eq 'Add';

    my $TemplateFile = 'AdminTicketChecklistNotificationsList';
    $TemplateFile = 'AdminTicketChecklistNotificationsForm' if $Self->{Subaction};

    return $LayoutObject->Output(
        TemplateFile => $TemplateFile,
        Data         => \%Param
    );
}

1;
