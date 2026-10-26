# --
# Kernel/Modules/AgentChecklistMyTodo.pm - manage the checklist for a ticket
# Copyright (C) 2014 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentChecklistMyTodo;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::Output::HTML::Layout
    Kernel::System::PerlServices::TicketChecklist
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

    my $ChecklistObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');
    my $LayoutObject    = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my @Todos = $ChecklistObject->TaskSearch(
        UserID => $Self->{UserID},
    );

    for my $Todo ( @Todos ) {
        $LayoutObject->Block(
            Name => 'Todo',
            Data => $Todo,
        );
    }

    if ( !@Todos ) {
        $LayoutObject->Block(
            Name => 'NoTodo',
        );
    }

    # print header
    my $Output = $LayoutObject->Header(
        Title => 'My Todos',
    );

    $Output .= $LayoutObject->NavigationBar();
    $Output .= $LayoutObject->Output(
        TemplateFile => 'AgentChecklistMyTodo',
    );

    $Output .= $LayoutObject->Footer();

    return $Output;
}

1;
