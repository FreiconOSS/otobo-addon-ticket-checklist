# --
# Kernel/Output/HTML/FilterElementPost/TicketChecklistDropdown.pm
# Copyright (C) 2015 - 2022 Perl-Services.de, https://www.perl-services.de/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::FilterElementPost::TicketChecklistDropdown;

use strict;
use warnings;

use List::Util qw(first);

our @ObjectDependencies = qw(
    Kernel::Config
    Kernel::Output::HTML::Layout
    Kernel::System::JSON
    Kernel::System::PerlServices::TicketChecklist
    Kernel::System::PerlServices::TicketChecklistTemplate
    Kernel::System::Web::Request
    Kernel::System::Group
    Kernel::System::AuthSession
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{UserID} = $Param{UserID};

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $TicketChecklistObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');
    my $TemplateObject        = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistTemplate');
    my $LayoutObject          = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ConfigObject          = $Kernel::OM->Get('Kernel::Config');
    my $LanguageObject        = $Kernel::OM->Get('Kernel::Language');
    my $JSONObject            = $Kernel::OM->Get('Kernel::System::JSON');
    my $ParamObject           = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $GroupObject           = $Kernel::OM->Get('Kernel::System::Group');
    my $SessionObject         = $Kernel::OM->Get('Kernel::System::AuthSession');

    # get template name
    my $Templatename = $Param{TemplateFile} || '';

    return 1 if !$Templatename;
    return 1 if !$Param{Templates}->{$Templatename};

    my %Session = $SessionObject->GetSessionIDData( SessionID => $LayoutObject->{SessionID} );

    my @UserGroups   = $GroupObject->GroupMemberList(
        UserID => $Self->{UserID} || $Param{UserID} || $LayoutObject->{UserID} || $Session{UserID},
        Result => 'ID',
        Type   => 'rw',
    );

    my %TemplateList = $TemplateObject->TemplateList(
        GroupIDs    => [ @UserGroups ],
        Valid       => 1,
        CustomerIDs => [],
    );

    return 1 if !%TemplateList;

    $Param{TemplateSelect} = $LayoutObject->BuildSelection(
        Name         => 'TicketChecklistID',
        Data         => \%TemplateList,
        PossibleNone => 1,
        AutoComplete => 'off',
        Class        => 'Modernize',
    );

    $LayoutObject->AddJSOnDocumentComplete(
        Code => qq~
            PS.ChecklistDropdown.Init();
        ~,
    );

    my $MultiChecklistCheckbox = '';
    my $ShowWidget = $ConfigObject->Get('TicketChecklist::ShowChecklistInTicketCreate');
    if ( $ShowWidget && $ConfigObject->Get('TicketChecklist::AllowMultiChecklistsInTicketCreate' ) ) {
        my $Label = $LanguageObject->Translate("Add items to existing checklist");

        $MultiChecklistCheckbox = sprintf q~
            <input type="checkbox" id="TicketChecklist-MultiChecklist" value="1"> %s
        ~, $Label;
    }

    my $ChecklistString = $LanguageObject->Translate("Checklist");
    my $Template = qq~
            <script type="text/javascript">
                function ReloadChecklist() {
                    PS.ChecklistDropdown.ReloadChecklist();
                }
            </script>
        <label for="TicketChecklistID">$ChecklistString</label>
        <div class="Field">
            $Param{TemplateSelect}
            $MultiChecklistCheckbox
        </div>
    ~;

    my $HiddenField = $Templatename eq 'AgentTicketEmail' ? 'TicketID' : 'FromChatID';

    ${ $Param{Data} } =~ s{
        <input \s+ type="hidden" \s+ name="$HiddenField" [^>]+> \s+
        <fieldset \s+ class="TableLike">\K

    }{
        $Template
    }xms;


    return 1;
}

1;
