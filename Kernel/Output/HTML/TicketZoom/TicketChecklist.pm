# --
# Copyright (C) 2014 - 2022 Perl-Services.de, https://www.perl-services.de/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::TicketZoom::TicketChecklist;

use strict;
use warnings;

use List::Util qw(first);

our @ObjectDependencies = qw(
    Kernel::System::Ticket
    Kernel::System::Log
    Kernel::System::Main
    Kernel::System::Web::Request
    Kernel::Output::HTML::Layout
    Kernel::Config
    Kernel::System::User
    Kernel::System::PerlServices::TicketChecklist
    Kernel::System::PerlServices::TicketChecklistStatus
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

    my $ParamObject      = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $ChecklistObject  = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');
    my $TicketInfoObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistTicketInfo');
    my $StatusObject     = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistStatus');
    my $LayoutObject     = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ConfigObject     = $Kernel::OM->Get('Kernel::Config');
    my $TicketObject     = $Kernel::OM->Get('Kernel::System::Ticket');
    my $LogObject        = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject       = $Kernel::OM->Get('Kernel::System::Main');
    my $UserObject       = $Kernel::OM->Get('Kernel::System::User');
    my $GroupObject      = $Kernel::OM->Get('Kernel::System::Group');
    my $HTMLUtilsObject  = $Kernel::OM->Get('Kernel::System::HTMLUtils');

    # define if rich text should be used
    my ($TicketID) = $ParamObject->GetParam( Param => 'TicketID' );

    if ( !$TicketID ) {
        my ($TicketNumber) = $ParamObject->GetParam( Param => 'TicketNumber' );
        $TicketID          = $TicketObject->TicketIDLookup(
            TicketNumber => $TicketNumber,
            UserID       => $Self->{UserID} // $LayoutObject->{UserID},
        );
    }

    return {} if !$TicketID;

    $Self->{UserID} //= $LayoutObject->{UserID};

    # check permissions
    my $Access = $TicketObject->TicketPermission(
        Type     => 'ro',
        TicketID => $Self->{TicketID},
        UserID   => $Self->{UserID}
    );

    my @ChecklistItems = $ChecklistObject->TicketChecklistTicketGet(
        TicketID => $TicketID,
    );

    return {} if !@ChecklistItems;

    my $Location = $Param{Config}->{Location} || 'Sidebar';
    my $ViewMode = $Location eq 'Main' ? 'Complex' : 'Simple';

    my %Info = $TicketInfoObject->GetInfo(
        TicketID => $TicketID,
    );

    $LayoutObject->Block(
        Name => $ViewMode . 'View',
        Data => {
            TicketID                  => $TicketID,
            CustomerVisibilityChecked => ( $Info{CustomerVisibility} ? 'checked="checked"' : '' ),
        },
    );

    my $Prefix = $ViewMode eq 'Complex' ? 'Complex' : '';

    my %Ticket = $TicketObject->TicketGet(
        TicketID => $TicketID,
        UserID   => $Self->{UserID},
    );

    my $IsOwner = $Ticket{OwnerID} == $Self->{UserID};

    my %Roles = $GroupObject->PermissionUserRoleGet(
        UserID => $Self->{UserID},
    );

    my %StatusList = $StatusObject->TicketChecklistStatusList(
        Queues => [ $Ticket{QueueID} ],
        Roles  => [ keys %Roles ],
    );

    my %StatusColors;

    for my $StatusID ( keys %StatusList ) {
        my %StatusInfo = $StatusObject->TicketChecklistStatusGet(
            ID => $StatusID,
        );

        $StatusColors{$StatusID} = $StatusInfo{Color};
    }

    my %UserData = $UserObject->GetUserData( UserID => $Self->{UserID} );

    my $UseAutocomplete    = $ConfigObject->Get('TicketChecklist::ResponsibleAutocomplete');
    my $AutocompleteModule = $ConfigObject->Get('TicketChecklist::ResponsibleAutocompleteModule') // 'Agent';

    my @PossibleValues;

    if ( $UseAutocomplete ) {
        my $AutocompleteObject = $Kernel::OM->Get(
           'Kernel::System::PerlServices::TicketChecklist::Autocomplete::' . $AutocompleteModule
        );

        @PossibleValues = $AutocompleteObject->MemberOfList(
            %UserData,
        );
    }

    my $DetailMode  = $ConfigObject->Get('TicketChecklist::DetailsInWidget') || 'Link';
    my $ShowDetails = $DetailMode ne 'None' ? 1 : 0;

    my $ItemsShown   = 0;
    my @HiddenStates = @{ $ConfigObject->Get('TicketChecklist::HiddenStates') || [] };

    my $ChangeNoteAsHTML    = $ConfigObject->Get('TicketChecklist::ChangeNote::ASCII2HTML');
    my $ChangeNoteLinkQuote = $ConfigObject->Get('TicketChecklist::ChangeNote::URLAutolink');

    my $CommentAsHTML       = $ConfigObject->Get('TicketChecklist::Comment::ASCII2HTML');
    my $CommentLinkQuote    = $ConfigObject->Get('TicketChecklist::Comment::URLAutolink');

    my $AllAgentsStatusChange = $ConfigObject->Get('TicketChecklist::AllAgentsStatusChange');

    my $ShowHiddenItemsParam = $ParamObject->GetParam( Param => 'PSTicketChecklistShowHiddenItems');
    my %Preferences          = $UserObject->GetPreferences(
        UserID => $Self->{UserID},
    );

    my %ChecklistPreferences = map{ $_ => 1 }( split /#/, $Preferences{PSTicketChecklistShowHiddenItems} // '' ); 

    if ( $ShowHiddenItemsParam ) {

        if ( $ShowHiddenItemsParam == 1 ) {
            $ChecklistPreferences{$TicketID} = 1;
        }
        else {
            delete $ChecklistPreferences{$TicketID};
        }

        $UserObject->SetPreferences(
            UserID => $Self->{UserID},
            Key    => 'PSTicketChecklistShowHiddenItems',
            Value  => (join '#', keys %ChecklistPreferences ),
        );
    }

    my $ShowHiddenItems = $ChecklistPreferences{$TicketID};

    CHECKITEM:
    for my $CheckItem ( @ChecklistItems ) {
        if( !grep{ $_ eq $CheckItem->{Status} }@HiddenStates ) {
            next CHECKITEM;
        }

        if ( !$ShowHiddenItems ) {
            $LayoutObject->Block(
                Name => $Prefix . 'HiddenItemsWarning',
                Data => { TicketID => $TicketID },
            );
        }
        else {
            $LayoutObject->Block(
                Name => $Prefix . 'HideItemsLink',
                Data => { TicketID => $TicketID },
            );
        }


        last CHECKITEM;
    }

    ITEM:
    for my $Item ( @ChecklistItems ) {
        if ( !$ShowHiddenItems && grep{ $_ eq $Item->{Status} }@HiddenStates ) {
            next ITEM;
        }

        $ItemsShown++;

        $Item->{StatusSelect} = sprintf "(%s)", $LayoutObject->{LanguageObject}->Translate( $StatusList{ $Item->{StatusID} } );

        $Item->{ResponsibleID}  //= 0;
        $Item->{ResponsibleKey} //= '';

        my $IsResponsible =
            $Item->{ResponsibleID} == $Self->{UserID} ||
            grep{ $_ eq $Item->{ResponsibleKey} }@PossibleValues;

        if (
            ( $Item->{ResponsibleID} == 1 && !$Item->{ResponsibleKey} ) ||
            ( !$Item->{ResponsibleID} && $AutocompleteModule eq 'Agent' &&
                ($Item->{ResponsibleKey} == $Self->{UserID} || $Item->{ResponsibleKey} == 1 ) ) ||
            ( !$Item->{ResponsibleID} && !$Item->{ResponsibleKey} )
        ) {
            $IsResponsible = 1;
        }

        if ( $AllAgentsStatusChange ) {
            $IsResponsible = 1;
        }

        if ( $IsOwner || $IsResponsible ) {
            $Item->{StatusSelect} = $LayoutObject->BuildSelection(
                Name         => 'ItemStatusWidget_' . $Item->{Position},
                Data         => \%StatusList,
                SelectedID   => $Item->{StatusID},
                Translation  => 1,
                AutoComplete => 'off',
                Class        => 'Modernize W75pc',
            );
        }

        $Item->{Color} = $StatusColors{ $Item->{StatusID} };

        $LayoutObject->Block(
            Name => $Prefix . 'Item',
            Data => $Item,
        );

        if ( $ShowDetails ) {
            if ( $DetailMode eq 'Link' ) {
                $LayoutObject->Block(
                    Name => $Prefix . 'TaskDetailsLink',
                    Data => $Item,
                );
            }

            $LayoutObject->Block(
                Name => $Prefix . 'TaskDetails',
                Data => $Item,
            );

            my $Comment = $Item->{Comment};
            my $Format  = 'Plain';

            if ( $CommentAsHTML ) {
                $Format  = 'HTML';
                $Comment = $HTMLUtilsObject->ToHTML(
                    String => $Comment // '',
                );

                if ( $CommentLinkQuote ) {
                    $Comment = $HTMLUtilsObject->LinkQuote(
                        String => $Comment // '',
                    );
                }
            }

            $LayoutObject->Block(
                Name => $Prefix . 'Comment' . $Format,
                Data => {
                    Comment => $Comment,
                },
            );
        }

        if ( !$Item->{ArticleID} ) {
            $LayoutObject->Block(
                Name => $Prefix . 'TitlePlain',
                Data => $Item,
            );
        }
        elsif ( $Item->{ArticleNumber} =~ m{[#]}xms ) {
            my ($TicketNumber) = split /\#/, $Item->{ArticleNumber};
            my $TicketID       = $TicketObject->TicketIDLookup(
                TicketNumber => $TicketNumber,
            );

            $Item->{TicketID} = $TicketID;

            $LayoutObject->Block(
                Name => $Prefix . 'TitleTicketLink',
                Data => $Item,
            );

            $LayoutObject->Block(
                Name => $Prefix . 'ArticleTicketLink',
                Data => $Item,
            );
        } 
        else {
            $LayoutObject->Block(
                Name => $Prefix . 'TitleLink',
                Data => $Item,
            );

            $LayoutObject->Block(
                Name => $Prefix . 'ArticleLink',
                Data => $Item,
            );
        }

        if ( $ConfigObject->Get('TicketChecklist::SaveChangeNote') ) {
            $LayoutObject->Block(
                Name => $Prefix . 'ChangeNoteDetail',
                Data => $Item,
            );

            my $ChangeNote = $Item->{ChangeNote};
            my $Format     = 'Plain';

            if ( $ChangeNoteAsHTML ) {
                $Format = 'HTML';

                # ascii -> html
                $ChangeNote = $HTMLUtilsObject->ToHTML(
                    String => $ChangeNote,
                );

                if ( $ChangeNoteLinkQuote ) {

                    # filter value
                    $ChangeNote = $HTMLUtilsObject->LinkQuote(
                        String => $ChangeNote,
                    );
                }
            }

            $LayoutObject->Block(
                Name => $Prefix . 'ChangeNoteDetail' . $Format,
                Data => {
                    ChangeNote => $ChangeNote,
                },
            );
        }

        if ( $DetailMode eq 'Link' ) {
            $LayoutObject->Block(
                Name => $Prefix . 'TaskDetailsClose',
            );
        }
    }

    return {} if !$ItemsShown;

    # show export buttons
    my $ShowExportIcons = $ConfigObject->Get('TicketChecklist::ShowExportIcons') || {};
    if ( $ShowExportIcons->{TicketZoom} ) {
        $LayoutObject->Block(
            Name => $Prefix . 'ExportIcons',
            Data => {
                TicketID => $TicketID,
            },
        );

        eval {
            require Excel::Writer::XLSX;
            1;
        } and do {
            $LayoutObject->Block(
                Name => $Prefix . 'ExportIconsXLSX',
                Data => {
                    TicketID => $TicketID,
                },
            );
        };

        eval {
            require Data::ICal;
            require Date::ICal;
            1;
        } and do {
            $LayoutObject->Block(
                Name => $Prefix . 'ExportIconsICS',
                Data => {
                    TicketID => $TicketID,
                },
            );
        };
    }

    my $ShowChangeNote      = $ConfigObject->Get('TicketChecklist::ShowChangeNotesWidget') ? 1 : 0;
    my $MandatoryChangeNote = $ConfigObject->Get('TicketChecklist::ChangeNotesMandatory') ? 1 : 0;
    my $SaveChangeNote      = $ConfigObject->Get('TicketChecklist::SaveChangeNote') ? 1 : 0;
    my $ReloadChecklist     = $ConfigObject->Get('TicketChecklist::ReloadChecklist') ? 1 : 0;
    my $ReloadTicketZoom    = $ConfigObject->Get('TicketChecklist::ReloadTicketZoom') ? 1 : 0;
    my $DetailsOnMouseOver  = $DetailMode eq 'MouseOver' ? 1 : 0;
    my $MoveChecklistTop    = $Param{Config}->{Top}      ? 1 : 0;

    my $Snippet = $LayoutObject->Output(
        TemplateFile => 'TicketChecklistWidget',
        Data         => {
            TicketID         => $TicketID,
            ShowChangeNote   => $ShowChangeNote,
            ReloadChecklist  => $ReloadChecklist,
            ReloadTicketZoom => $ReloadTicketZoom,
            DetailsMouseOver => $DetailsOnMouseOver,
            Prefix           => $Prefix,

            MandatoryChangeNote            => $MandatoryChangeNote,
            MoveChecklistAfterArticleItems => $MoveChecklistTop,
        },
    );

    if ( $Param{ReturnHTML} ) {
        return $Snippet;
    }

    return {
        Output => $Snippet,
    };
}

1;
