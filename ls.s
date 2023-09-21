* ls - list directories and files
*
* Itagaki Fumihiko 03-Dec-92  Create.
* 1.0
* Itagaki Fumihiko 06-Dec-92  Debug and brush up.
* 1.1
* Itagaki Fumihiko 08-Dec-92  �{�����[���E���x���̃N���X�^�����������v��
* Itagaki Fumihiko 16-Dec-92  / �̍ŏI�X�V������ 0-0-0 ���� 0-1-1 �ɕύX
* Itagaki Fumihiko 23-Dec-92  -V �I�v�V�����̒ǉ�
* Itagaki Fumihiko 10-Jan-93  GETPDB -> lea $10(a0),a0
* Itagaki Fumihiko 20-Jan-93  ���� - �� -- �̈����̕ύX
* Itagaki Fumihiko 22-Jan-93  �X�^�b�N���g��
* 1.2
* Itagaki Fumihiko 04-Feb-93  LNDRV_realpathcpy->LNDRV_O_FILES �� LNDRV_LINK_FILES �ɕύX
* Itagaki Fumihiko 06-Feb-93  JOIN���ꂽ�h���C�u���̃T�u�f�B���N�g���ɂ�-V�������悤�C��
* Itagaki Fumihiko 06-Feb-93  ���΃p�X�Őݒ肳�ꂽ�V���{���b�N�E�����N������������
* Itagaki Fumihiko 06-Feb-93  ���[�v�����V���{���b�N�E�����N������������
* Itagaki Fumihiko 07-Feb-93  �����̖����� / ���t���Ă���΁C���ꂪ�f�B���N�g���ւ̃V���{
*                             ���b�N�E�����N�ł���Ƃ��ɁC-l �I�v�V������ -v �I�v�V������
*                             �w�肳��Ă��Ă��f�B���N�g�������Ƃ��ď�������
* 1.3
*
* Usage: ls [ -1ABCDFGLQRSUVXabdeflmpqrstvx ] [ -w cols ] [ -- ] [ file ] ...
*
* �I�v�V������ǉ�����Ƃ��͒��ӂ��K�v�C
* �����炱����Ńt���O���`�F�b�N���āA���ʂȏ������Ȃ��Ă���D
*
* �����Ă�����̂͊o�債�Ă�����ׂ��D

.include doscall.h
.include error.h
.include limits.h
.include stat.h
.include chrcode.h

.xref DecodeHUPAIR
.xref getlnenv
.xref issjis
.xref toupper
.xref atou
.xref utoa
.xref utoao
.xref strlen
.xref strchr
.xref strcmp
.xref stricmp
.xref strcpy
.xref stpcpy
.xref strbot
.xref strfor1
.xref memmovi
.xref memset
.xref mulul
.xref divul
.xref bsltosl
.xref strip_excessive_slashes
.xref headtail
.xref suffix
.xref contains_dos_wildcard
.xref getenv
.xref printfi

REQUIRED_OSVER		equ	$200			*  2.00�ȍ~
BLOCKSIZE		equ	1024
OLDEST_DATIME		equ	((1<<5)|1)<<16

MAXRECURSE	equ	64	*  �T�u�f�B���N�g�����������邽�߂ɍċA����񐔂̏���D
				*  MAXDIR �i�p�X���̃f�B���N�g���� "/1/2/3/../" �̒����j
				*  �� 64 �ł��邩��A31�ŏ[���ł��邪�C
				*  �V���{���b�N�E�����N���l������ 64 �Ƃ���D
				*  �X�^�b�N�ʂɂ������D
DEFAULT_COLUMNS	equ	80
LINEBUFSIZE	equ	1024
FILELIST_UNIT	equ	32	*  2�ׂ̂���łȂ���΂Ȃ�Ȃ�
FATCHK_STATIC	equ	256	*  �ÓI�o�b�t�@��fatchk�ł���悤�ɂ��Ă���FAT�`�F�C����
********************************
* ENTRY�\����
********************************
.offset 0
entry_name:	ds.b	MAXPATH+1
entry_flag:	ds.b	1
entry_mode:	ds.b	1
entry_linkmode:	ds.b	1
.even
entry_drive:	ds.w	1
entry_datime:
entry_date:	ds.w	1
entry_time:	ds.w	1
entry_size:	ds.l	1
entry_nblocks:	ds.l	1
entry_linkpath:	ds.l	1
.even
entry_struct_size:

* entry_flag �̃r�b�g�̒�`
FLAGBIT_SUBDIR	equ	0
FLAGBIT_NOSTAT	equ	1
FLAGBIT_IGNORE	equ	2
FLAGBIT_ALLOC	equ	3

LNDRV_O_CREATE		equ	4*2
LNDRV_O_OPEN		equ	4*3
LNDRV_O_DELETE		equ	4*4
LNDRV_O_MKDIR		equ	4*5
LNDRV_O_RMDIR		equ	4*6
LNDRV_O_CHDIR		equ	4*7
LNDRV_O_CHMOD		equ	4*8
LNDRV_O_FILES		equ	4*9
LNDRV_O_RENAME		equ	4*10
LNDRV_O_NEWFILE		equ	4*11
LNDRV_O_FATCHK		equ	4*12
LNDRV_realpathcpy	equ	4*16
LNDRV_LINK_FILES	equ	4*17
LNDRV_OLD_LINK_FILES	equ	4*18
LNDRV_link_nest_max	equ	4*19
LNDRV_getrealpath	equ	4*20

****************************************************************
.text

start:
		bra.s	start1
		dc.b	'#HUPAIR',0
start1:
		lea	stack_bottom,a7			*  A7 := �X�^�b�N�̒�
		DOS	_VERNUM
		cmp.w	#REQUIRED_OSVER,d0
		bcs	dos_version_mismatch

		lea	$10(a0),a0			*  A0 : PDB�A�h���X
		move.l	a7,d0
		sub.l	a0,d0
		move.l	d0,-(a7)
		move.l	a0,-(a7)
		DOS	_SETBLOCK
		addq.l	#8,a7
	*
	*  �����ł͂Ȃ��N��\������͈͂����肷��D
	*
		DOS	_GETDATE
		move.w	d0,present_date
		moveq	#0,d1
		move.w	d0,d1
		and.w	#$fe00,d1			*  �N
		move.w	d0,d2
		and.w	#$01ff,d2			*  ����
		and.w	#$01e0,d0			*  ��
		cmp.w	#$00e0,d0			*  7��
		blo	six_month_ago_1

		sub.w	#$00c0,d2			*  ����-6��
		add.l	#$0200,d1			*  +1�N(�Q�^)
		bra	six_month_ago_ok

six_month_ago_1:
		add.w	#$00c0,d2			*  ����+6��
							*  ������1�N�����Ȃ���΂Ȃ�Ȃ��̂�
							*  +1�N�̃Q�^�͑��E
six_month_ago_ok:
		or.w	d2,d1				*  �N+1�N-6��
		move.l	d1,cutoff_date
	*
	*  �[���̕��𓾂�
	*
		lea	word_COLUMNS(pc),a0
		bsr	getenv
		beq	columns_default

		movea.l	d0,a0
		bsr	atou
		bne	columns_default

		move.l	d1,d0
		bne	columns_ok

		moveq	#1,d0
		bra	columns_ok

columns_default:
		move.l	#DEFAULT_COLUMNS,d0
columns_ok:
		move.l	d0,columns
	*
	*  �o�͏��������߂�
	*
		moveq	#0,d1				*  -1
		moveq	#1,d0				*  �o�͂�
		bsr	is_chrdev			*  �u���b�N�E�f�o�C�X���H
		beq	set_default_format		*  -- �u���b�N�E�f�o�C�X�ł���

		moveq	#1,d1				*  -C
set_default_format:
		move.b	d1,format
		lea	cmp_name(pc),a0
		move.l	a0,cmp_func
	*
	*  lndrv�풓�`�F�b�N
	*
		bsr	getlnenv
		move.l	d0,lndrv
	*
	*  �������ъi�[�G���A���m�ۂ���
	*
		lea	1(a2),a0			*  A0 := �R�}���h���C���̕�����̐擪�A�h���X
		bsr	strlen				*  D0.L := �R�}���h���C���̕�����̒���
		addq.l	#1,d0
		bsr	malloc
		bmi	insufficient_memory

		movea.l	d0,a1				*  A1 := �������ъi�[�G���A�̐擪�A�h���X
	*
	*  �������f�R�[�h���C���߂���
	*
		bsr	DecodeHUPAIR			*  �������f�R�[�h����
		movea.l	a1,a0				*  A0 : �����|�C���^
		move.l	d0,d7				*  D7.L : �����J�E���^
decode_opt_loop1:
		tst.l	d7
		beq	decode_opt_done

		cmpi.b	#'-',(a0)
		bne	decode_opt_done

		tst.b	1(a0)
		beq	decode_opt_done

		subq.l	#1,d7
		addq.l	#1,a0
		move.b	(a0)+,d0
		cmp.b	#'-',d0
		bne	decode_opt_loop2

		tst.b	(a0)+
		beq	decode_opt_done

		subq.l	#1,a0
decode_opt_loop2:
		cmp.b	#'f',d0
		beq	opt_f

		cmp.b	#'e',d0
		beq	opt_e

		cmp.b	#'s',d0
		beq	opt_s

		cmp.b	#'V',d0
		beq	opt_V

		cmp.b	#'R',d0
		beq	opt_R

		cmp.b	#'L',d0
		beq	opt_L

		cmp.b	#'d',d0
		beq	opt_d

		cmp.b	#'Q',d0
		beq	opt_Q

		cmp.b	#'D',d0
		beq	opt_D

		cmp.b	#'r',d0
		beq	opt_r

		cmp.b	#'G',d0
		beq	opt_G

		cmp.b	#'v',d0
		beq	opt_v

		cmp.b	#'l',d0
		beq	opt_l

		cmp.b	#'B',d0
		beq	opt_B

		cmp.b	#'a',d0
		beq	opt_a

		cmp.b	#'A',d0
		beq	opt_A

		cmp.b	#'p',d0
		beq	opt_p

		cmp.b	#'F',d0
		beq	opt_F

		moveq	#1,d1
		cmp.b	#'q',d0
		beq	set_escape

		moveq	#2,d1
		cmp.b	#'b',d0
		beq	set_escape

		moveq	#0,d1
		cmp.b	#'1',d0
		beq	set_format

		moveq	#1,d1
		cmp.b	#'C',d0
		beq	set_format

		moveq	#2,d1
		cmp.b	#'x',d0
		beq	set_format

		moveq	#3,d1
		cmp.b	#'m',d0
		beq	set_format

		clr.l	a1
		cmp.b	#'U',d0
		beq	set_cmp_func

		lea	cmp_extention(pc),a1
		cmp.b	#'X',d0
		beq	set_cmp_func

		lea	cmp_time(pc),a1
		cmp.b	#'t',d0
		beq	set_cmp_func

		lea	cmp_size(pc),a1
		cmp.b	#'S',d0
		beq	set_cmp_func

		cmp.b	#'w',d0
		beq	parse_width

		moveq	#1,d1
		tst.b	(a0)
		beq	bad_option_1

		bsr	issjis
		bne	bad_option_1

		moveq	#2,d1
bad_option_1:
		move.l	d1,-(a7)
		pea	-1(a0)
		move.w	#2,-(a7)
		lea	msg_illegal_option(pc),a0
		bsr	werror_myname_and_msg
		DOS	_WRITE
		lea	10(a7),a7
		bra	usage

parse_width:
		tst.b	(a0)+
		bne	bad_arg

		subq.l	#1,d7
		bcs	too_few_args

		bsr	atou
		bne	bad_width

		tst.b	(a0)+
		bne	bad_width

		tst.l	d1
		beq	bad_width

		move.l	d1,columns
		bra	decode_opt_loop1

set_escape:
		move.b	d1,escape
		bra	set_option_done

set_format:
		move.b	d1,format
		bra	set_option_done

set_cmp_func:
		move.l	a1,cmp_func
		bra	set_option_done

opt_f:
		st	fast
		bra	set_option_done

opt_e:
		st	exploration
		bra	set_option_done

opt_v:
		st	long_datime
		bra	set_long_format

opt_l:
		sf	long_datime
set_long_format:
		st	long_format
		bra	set_option_done

opt_Q:
		st	quote
		bra	set_option_done

opt_R:
		st	recurse
		bra	set_option_done

opt_L:
		st	replace_link
		bra	set_option_done

opt_a:
		st	show_all
opt_A:
		st	show_almost_all
		bra	set_option_done

opt_B:
		st	not_show_backfiles
		bra	set_option_done

opt_d:
		st	directory
		bra	set_option_done

opt_F:
		st	mark_exes
opt_p:
		st	mark_dirs
		bra	set_option_done

opt_D:
		st	case_insensitive
		bra	set_option_done

opt_r:
		st	reverse
		bra	set_option_done

opt_G:
		st	gather
		bra	set_option_done

opt_s:
		st	print_nblocks
		bra	set_option_done

opt_V:
		st	virtual_dir_size
set_option_done:
		move.b	(a0)+,d0
		bne	decode_opt_loop2
		bra	decode_opt_loop1

decode_opt_done:
	*
	*  -f�I�v�V�����̏���
	*
		tst.b	fast
		beq	fast_flag_ok

		clr.l	cmp_func
		st	show_all
		st	exploration
		sf	not_show_backfiles
		sf	recurse
		sf	directory
		sf	replace_link
		sf	print_nblocks
		sf	mark_dirs
		sf	long_format
fast_flag_ok:
	*
	*  �N���X�^�E�T�C�Y�𓾂�K�v�����邩�ǂ������ׂ�
	*
		move.b	print_nblocks,d0
		or.b	long_format,d0
		sne	needs_nblocks
	*
	*  �e.�f�Ɓe..�f�� stat �𓾂�K�v�����邩�ǂ������ׂ�
	*
		st	needs_dots_stat
		cmpi.l	#cmp_time,cmp_func
		beq	needs_dots_stat_ok

		cmpi.l	#cmp_size,cmp_func
		beq	needs_dots_stat_ok

		tst.b	needs_nblocks
		sne	needs_dots_stat
needs_dots_stat_ok:
	*
	*  -L �̌��ʂ��`�F�b�N����
	*
		move.b	needs_dots_stat,d0
		or.b	mark_dirs,d0
		or.b	recurse,d0
		bne	replace_link_ok

		sf	replace_link			*  -L �Ɍ��ʂ͖����B�ނ���B
replace_link_ok:
	*
	*  -V �̌��ʂ��`�F�b�N����
	*
		tst.b	long_format
		bne	virtual_dir_size_ok

		cmpi.l	#cmp_size,cmp_func
		beq	virtual_dir_size_ok

		sf	virtual_dir_size
virtual_dir_size_ok:
	*
	*  �t�@�C����������������
	*
		lea	_linebuf(pc),a1
		move.l	a1,_bufp
		move.l	#LINEBUFSIZE,_buf_remain

		tst.l	d7
		bne	args_ok

		lea	default_arg(pc),a0
		moveq	#1,d7
args_ok:
	*
	*  ������stat���郋�[�v
	*
		clr.w	exitcode
		clr.l	entry_top
		clr.l	number_of_entry
		clr.l	number_of_subdir
		st	have_to_headtail
ls_args_loop:
		movea.l	a0,a1
		bsr	strfor1
		exg	a0,a1
		move.b	(a0),d0
		beq	ls_args_1

		cmpi.b	#':',1(a0)
		bne	ls_args_1

		bsr	toupper
		move.b	d0,(a0)
ls_args_1:
		bsr	doname
		movea.l	a1,a0
		subq.l	#1,d7
		bne	ls_args_loop
	*
	*  �o��
	*
		move.l	number_of_entry,d0
		beq	exit_program_with_exitcode

		movea.l	entry_top,a0
		bsr	sort
sort_args_done:
		tst.b	directory
		beq	split_directory
	*
	*  -d ���w�肳��Ă��� ... ��f�B���N�g���ƃf�B���N�g�����܂Ƃ߂ďo��
	*
		movea.l	entry_top,a0
		move.l	number_of_entry,d0
		bsr	output
		bra	exit_program_with_exitcode

split_directory:
	*
	*  ��f�B���N�g���ƃf�B���N�g���𕪂��ďo�͂���
	*
		move.l	number_of_entry,d3
		sub.l	number_of_subdir,d3		*  D3.L : ��f�B���N�g�������̐�
		beq	ls_dirargs
		*
		*  ��f�B���N�g�����܂Ƃ߂ďo��
		*
		move.l	d3,d0
		lsl.l	#2,d0
		bsr	malloc
		bmi	insufficient_memory

		movea.l	d0,a0
		movea.l	entry_top,a2
		movea.l	a0,a1
		move.l	d3,d0
		bra	copy_nondir_list_continue

copy_nondir_list_high_loop:
		swap	d0
copy_nondir_list_loop:
		movea.l	(a2)+,a3
		btst.b	#FLAGBIT_SUBDIR,entry_flag(a3)
		bne	copy_nondir_list_loop

		move.l	a3,(a1)+
copy_nondir_list_continue:
		dbra	d0,copy_nondir_list_loop

		swap	d0
		dbra	d0,copy_nondir_list_high_loop

		move.l	d3,d0
		bsr	output
		move.l	a0,d0
		bsr	free
ls_dirargs:
		*
		*  �f�B���N�g���͌ʂɂ��̓��e���o��
		*
		move.b	#1,print_dirheader		*  1 : ���s���ăf�B���N�g���E�w�b�_���o�͂���
		tst.l	d3				*  D3.L == ��f�B���N�g�������̐�
		bne	do_ls_dirargs

		move.b	#-1,print_dirheader		*  -1 : ���s�����Ƀf�B���N�g���E�w�b�_���o�͂���
		move.l	number_of_subdir,d0
		subq.l	#1,d0
		bhi	do_ls_dirargs

		clr.b	print_dirheader			*  0 : �f�B���N�g���E�w�b�_���o�͂��Ȃ�
do_ls_dirargs:
		sf	have_to_headtail
		bsr	ls_subdir
exit_program_with_exitcode:
		move.w	exitcode,d0
exit_program:
		move.w	d0,-(a7)
		DOS	_EXIT2

bad_width:
		lea	msg_bad_width(pc),a0
		bra	bad_arg_1

too_few_args:
		lea	msg_too_few_args(pc),a0
		bra	bad_arg_1

bad_arg:
		lea	msg_bad_arg(pc),a0
bad_arg_1:
		bsr	werror_myname_and_msg
usage:
		lea	msg_usage(pc),a0
		bsr	werror
		moveq	#1,d0
		bra	exit_program

dos_version_mismatch:
		lea	msg_dos_version_mismatch(pc),a0
		bra	error_exit_3

insufficient_memory:
		lea	msg_no_memory(pc),a0
error_exit_3:
		bsr	werror_myname_and_msg
		moveq	#3,d0
		bra	exit_program
****************************************************************
* doname - 1�̈�������������
*
* CALL
*      A0     �����̐擪�A�h���X
*
* RETURN
*      D0.L   �j��
****************************************************************
doname:
		movem.l	d1-d3/a0-a5,-(a7)
		movea.l	a0,a5
		sf	slash
		bsr	bsltosl
		bsr	strlen
		subq.l	#1,d0
		bcs	doname_0

		cmpi.b	#'/',(a0,d0.l)
		seq	slash
doname_0:
		bsr	strip_excessive_slashes
		bsr	strlen
		cmp.l	#MAXPATH,d0
		bhi	doname_too_long_path

		bsr	contains_dos_wildcard
		bne	doname_nofile

		tst.b	exploration
		bne	doname_1

		movea.l	a0,a1
		bsr	lstat
		bpl	doname_done
doname_1:
		movea.l	a0,a4
		movea.l	a0,a2				*  A2 : pathname scanning pointer
		lea	pathname(pc),a3			*  A3 : pathname appending pointer
		move.l	#MAXPATH,d2			*  D2.L : A3 �̗e��
		cmpi.b	#':',1(a2)
		bne	doname_drive_ok

		move.b	(a2)+,(a3)+
		move.b	(a2)+,(a3)+
		subq.l	#2,d2
		bcs	doname_too_long_path
doname_drive_ok:
		cmpi.b	#'/',(a2)
		bne	doname_root_ok

		move.b	(a2)+,(a3)+
		subq.l	#1,d2
		bcs	doname_too_long_path
doname_root_ok:
		clr.b	(a3)
		lea	pathname(pc),a0
		tst.b	(a0)
		beq	doname_not_root

		tst.b	(a2)
		beq	doname_nostat
doname_not_root:
		movea.l	a4,a0
		tst.b	exploration
		beq	doname_try_nameck
doname_loop:
		move.l	a3,a4				*  A4 : pathname �̃t�@�C������
		move.l	d2,d3				*  D3.L : �����܂ł̎c��e��
		movea.l	a2,a0
		moveq	#'/',d0
		bsr	strchr
		exg	a0,a2
		move.b	(a2),d1
		clr.b	(a2)
		bsr	strlen
		sub.l	d0,d2
		bcs	doname_too_long_path

		movea.l	a0,a1
		movea.l	a3,a0
		bsr	stpcpy
		movea.l	a0,a3
		move.l	a1,a0
		bsr	is_reldir
		move.b	d1,(a2)
		lea	pathname(pc),a0
		tst.w	d0
		beq	doname_not_pseudo

		tst.b	(a2)
		bne	doname_continue			*  �p�X�̓r���� . �� .. �͌������Ȃ�
doname_try_nameck:
		lea	nameck_buffer(pc),a1
		bsr	dirnameck
		bmi	doname_nameck_fail		*  NAMECK�ł��Ȃ����� .. �ʏ폈����

		exg	a0,a1
		bsr	strip_excessive_slashes
		bsr	lstat
		exg	a0,a1
		bpl	doname_done

		tst.b	3(a1)
		bne	doname_nofile
doname_nostat:
		bsr	add_entry
		bsr	set_nostat
		bsr	test_subdir_bit
		bra	doname_return

doname_nameck_fail:
		tst.b	exploration
		beq	doname_not_pseudo
doname_nofile:
		movea.l	a5,a0
		bsr	werror_myname_and_msg
		lea	msg_nofile(pc),a0
		bsr	werror
		move.w	#2,exitcode
		bra	doname_return

doname_not_pseudo:
		bsr	lstat
		bmi	doname_nofile

		movea.l	a4,a3
		move.l	d3,d2
		movea.l	a0,a4				*  A4 : �o�^���閼�O�̐擪
		lea	tmp_filesbuf+ST_NAME(pc),a0
		bsr	strlen
		sub.l	d0,d2
		bcs	doname_too_long_path

		movea.l	a0,a1
		movea.l	a3,a0
		bsr	stpcpy
		movea.l	a0,a3
		movea.l	a4,a0
		movea.l	a0,a1
		tst.b	(a2)
		beq	doname_done
doname_continue:
		subq.l	#1,d2
		bcs	doname_too_long_path

		move.b	(a2)+,(a3)+
		bra	doname_loop

doname_done:
		move.l	a1,-(a7)
		bsr	add_entry
		lea	tmp_filesbuf(pc),a2
		bsr	copy_stat
		move.l	(a7)+,a0
		bsr	do_test_link
		cmpa.l	#0,a0
		beq	doname_return

		bsr	set_cluster_size
		*
		*  �������f�B���N�g���Ȃ�subdir�r�b�g��ON�ɂ���
		*
		btst.b	#MODEBIT_DIR,entry_mode(a1)
		bne	doname_set_subdir_bit
		*
		*  �������f�B���N�g���ւ̃V���{���b�N�E�����N�̂Ƃ���subdir�r�b�g��ON�ɂ���
		*
		*  ������ -l, -v �I�v�V�������w�肳��Ă���Ƃ��ɂ́C�t�@�C�������̖����� /
		*  ���t���Ă��Ȃ����subdir��ON�ɂ��Ȃ�
		*
		btst.b	#MODEBIT_DIR,entry_linkmode(a1)
		beq	doname_return

		tst.b	long_format			*  -l, -v
		beq	doname_set_subdir_bit

		tst.b	slash
		beq	doname_return
doname_set_subdir_bit:
		bset.b	#FLAGBIT_SUBDIR,entry_flag(a1)
		addq.l	#1,number_of_subdir
doname_return:
		movem.l	(a7)+,d1-d3/a0-a5
		rts

doname_too_long_path:
		movea.l	a5,a0
		bsr	too_long_path
		bra	doname_return
****************************************************************
* ls_subdir - ENTRY�\���̃A�h���X�z�񂩂�T�u�f�B���N�g����T���C
*             ���̃T�u�f�B���N�g�����̃t�@�C�����o�͂���
*
* CALL
*      entry_top         ENTRY�\���̃A�h���X�z��̐擪�A�h���X���i�[����Ă���
*      number_of_subdir  ENTRY�\���̂̂����T�u�f�B���N�g���̐�
*      print_dirheader   0 : �f�B���N�g���E�w�b�_���o�͂��Ȃ�
*                        1 : ���s���ăf�B���N�g���E�w�b�_���o�͂���
*                        -1 : ���s�����Ƀf�B���N�g���E�w�b�_���o�͂���
*
* RETURN
*      none
*
* NOTE
*      ENTRY�\���̃A�h���X�z��Ƃ��̗v�f�͂��ׂ�free�����D
*
*      -R�I�v�V�����w�莞�ɂ́C�f�B���N�g���̐[�������ċA����D
*      �X�^�b�N�ɒ��ӁD
****************************************************************
ls_subdir:
		movem.l	d0-d2/a0-a3,-(a7)
		lea	pathname(pc),a3
		bsr	ls_subdir_recurse
		movem.l	(a7)+,d0-d2/a0-a3
		rts
****************************************************************
* ls_onedir - �f�B���N�g�����I�[�v�����ĕ\������
*
* CALL
*      pathname          �f�B���N�g���̃p�X���i�[����Ă���
*                        ������ MAXHEAD �����ł��邱��
*                        �Ō�ɗ]�v�� / ���t���Ă��Ȃ�����
*
* RETURN
*      ���ׂĔj��
****************************************************************
ls_onedir:
		clr.l	entry_top
		clr.l	number_of_entry
		clr.l	number_of_subdir
		lea	pathname(pc),a0
		movea.l	a0,a3
		bsr	strbot
		exg	a0,a3
		move.l	a3,d0
		sub.l	a0,d0
		beq	ls_onedir_add_slash

		cmpi.b	#':',-1(a3)
		beq	ls_onedir_head_ok

		cmpi.b	#'/',-1(a3)
		beq	ls_onedir_head_ok
ls_onedir_add_slash:
		addq.l	#1,d0
		cmp.l	#MAXHEAD,d0
		bhi	too_long_path

		move.b	#'/',(a3)+
ls_onedir_head_ok:
		cmp.l	#MAXHEAD,d0
		bhi	too_long_path

		lea	str_dos_allfile(pc),a1
		exg	a0,a3
		bsr	strcpy
		exg	a0,a3
		lea	filesbuf(pc),a2
		move.w	#MODEVAL_ALL,-(a7)
		move.l	a0,-(a7)
		move.l	a2,-(a7)
		DOS	_FILES
		lea	10(a7),a7
				*  chdir �ō~��Ȃ��� files("*.*") ��������������Ƃ�������
				*  �m���߂�ꂽ���C�����Ȃ�Ƃ͌����Ă����X�S�̂�5%���x�ł�
				*  �邵�C�����ɂ���Ă͋t�ɒx���Ȃ邱�Ƃ��l������D����ɁC
				*
				*  o �f�B���N�g���ւ̃V���{���b�N�E�����N�ɍ~����
				*    chdir("..") �ł͖߂�Ȃ��̂ŁC���̏ꍇ�̓J�����g�E�f�B
				*    ���N�g����ۑ����Ă�������
				*
				*  o �f�B���N�g�������̏�����͂ǂ��ɂ��߂�Ȃ�����
				*
				*  o ^C�������ꂽ���ƃf�B���N�g���ɕ��A���Ă���I�����鏈
				*    ��
				*
				*  �Ȃǂ��s��˂΂Ȃ炸�C�v���O���������G�ɂȂ�D�����̏�
				*  �����e�K�v�ȏꍇ�����f�s���悤�ɂ���ƁC�v���O�����͂���
				*  �ɕ��G�ɂȂ�D
				*
				*  �܂��C�e�f�B���N�g���ւ̃V���{���b�N�E�����N�f�̃p�X����
				*  �� chdir �ł���Ƃ����O�񂪁C�����ɂ킽���ĕۏ؂���Ȃ���
				*  ���m��Ȃ��i�C�����Ȃ��ł��Ȃ��j�D�������� chdir �́e�w��
				*  �h���C�u�̃J�����g�E�f�B���N�g����ύX����f�t�@���N�V��
				*  ���ł��邩��C�h���C�u���܂������� chdir ���� lndrv 1.00
				*  �̎d�l�́CHuman68k �̖{���̎d�l���班�X��E���Ă���D����
				*  �悤�Ȋϓ_����Clndrv �� chdir �̎d�l�Ɉˑ�����̂͏��X��
				*  ���ƌ����D�Ȃ�� lndrv �� chdir �𒼐ڂ͌Ă΂��ɁC�ړI��
				*  �f�B���N�g���̃p�X���� readlink �ɂ��ǂݎ���� chdir ��
				*  ��Ηǂ��i���̏����́C���̃��[�`���ɓ��B����܂łɊ��ɍs
				*  ���Ă��锤�ł��邩��C���ԓI�ɑ����邱�Ƃ͂Ȃ��j�̂����C
				*  ������܂��v���O�����𕡎G�ɂ��Ă��܂��D
				*
				*  �Ƃ����킯�ŁCchdir�����͎̂Ă��D
				*
				*  ������ Human68k �ł́C���̂܂܂ł������Ȃ�\��������D
open_directory_loop:
		tst.l	d0
		bmi	open_directory_done

		lea	ST_NAME(a2),a0
		bsr	is_reldir
		move.w	d0,d3
		tst.b	show_all
		bne	hidden_ok

		tst.w	d3
		bne	open_directory_continue

		btst.b	#MODEBIT_VOL,ST_MODE(a2)
		bne	open_directory_continue

		tst.b	show_almost_all
		bne	hidden_ok

		cmpi.b	#'.',(a0)
		beq	open_directory_continue

		btst.b	#MODEBIT_HID,ST_MODE(a2)
		bne	open_directory_continue
hidden_ok:
		tst.b	not_show_backfiles
		beq	backfile_ok

		bsr	strlen
		lea	str_dotBAK(pc),a1
		moveq	#4,d1
		bsr	tailmatch
		beq	open_directory_continue

		lea	str_tilde(pc),a1
		moveq	#1,d1
		bsr	tailmatch
		beq	open_directory_continue
backfile_ok:
	*
	*  �G���g����o�^����
	*
		movea.l	a0,a1
		movea.l	a3,a0
		bsr	strcpy
		movea.l	a1,a0
		bsr	add_entry
		lea	pathname(pc),a0
		tst.w	d3
		beq	ls_onedir_add_entry_copy_stat

		tst.b	needs_dots_stat
		beq	ls_onedir_set_dots_nostat

		move.l	a1,-(a7)
		lea	nameck_buffer(pc),a1
		bsr	dirnameck
		movea.l	(a7)+,a1
		bmi	ls_onedir_set_dots_nostat

		lea	nameck_buffer(pc),a0
		bsr	strip_excessive_slashes
		bsr	lstat
		bpl	ls_onedir_add_entry_replace_stat
ls_onedir_set_dots_nostat:
		bsr	set_nostat
		bra	open_directory_continue

ls_onedir_add_entry_replace_stat:
		lea	tmp_filesbuf(pc),a2
ls_onedir_add_entry_copy_stat:
		bsr	copy_stat
		bsr	test_link_if_necessary
		cmpa.l	#0,a0
		beq	open_directory_continue

		bsr	set_cluster_size
		tst.w	d3				*  '.' �� '..' ���H
		bne	open_directory_continue

		bsr	test_subdir_bit
open_directory_continue:
		lea	filesbuf(pc),a2
		move.l	a2,-(a7)
		DOS	_NFILES
		addq.l	#4,a7
		bra	open_directory_loop

open_directory_done:
		tst.b	needs_nblocks
		beq	ls_onedir_print_total_done

		pea	str_total(pc)
		DOS	_PRINT
		addq.l	#4,a7
		moveq	#0,d0
		movea.l	entry_top,a1
		move.l	number_of_entry,d1
		bra	calc_total_continue

calc_total_high_loop:
		swap	d1
calc_total_low_loop:
		move.l	(a1)+,a0
		add.l	entry_nblocks(a0),d0
calc_total_continue:
		dbra	d1,calc_total_low_loop

		swap	d1
		dbra	d1,calc_total_high_loop

		lea	itoabuf(pc),a0
		bsr	utoa
		move.l	a0,-(a7)
		DOS	_PRINT
		pea	str_newline(pc)
		DOS	_PRINT
		addq.l	#8,a7
ls_onedir_print_total_done:
		move.l	number_of_entry,d0
		beq	free_list			*  ���X�g��free���ċA��

		movea.l	entry_top,a0
		bsr	sort
ls_onedir_sort_done:
		bsr	output
		tst.b	recurse
		beq	free_list			*  ���X�g��free���ċA��
ls_subdir_recurse:
		moveq	#0,d1
		movea.l	entry_top,a2
		move.l	number_of_subdir,d2
		bra	find_last_subdir_continue

find_last_subdir_high_loop:
		swap	d2
find_last_subdir_loop:
		movea.l	(a2)+,a0
		btst.b	#FLAGBIT_SUBDIR,entry_flag(a0)
		beq	find_last_subdir_loop

		move.l	a0,d1
find_last_subdir_continue:
		dbra	d2,find_last_subdir_loop

		swap	d2
		dbra	d2,find_last_subdir_high_loop

		tst.l	d1				*  D1.L : �Ō��ENTRY�\���̃A�h���X
		beq	ls_subdir_return

		movea.l	entry_top,a2			*  A2 : ENTRY�\���̃A�h���X�z��|�C���^
ls_subdir_loop:
		movea.l	(a2),a0
		btst.b	#FLAGBIT_SUBDIR,entry_flag(a0)
		beq	ls_subdir_continue

		lea	entry_name(a0),a1
		movea.l	a3,a0
		bsr	strcpy
		tst.b	print_dirheader
		beq	ls_subdir_header_ok
		bmi	ls_subdir_newline_ok

		lea	str_newline(pc),a1
		bsr	bufcpy
ls_subdir_newline_ok:
		lea	pathname(pc),a1
		bsr	bufcpy
		moveq	#':',d0
		bsr	bufout
		bsr	putline
ls_subdir_header_ok:
		move.b	#1,print_dirheader
		cmp.l	(a2)+,d1
		beq	ls_subdir_dolast

		cmpa.l	#stack_lower+24,a7		*  �ċA�ɔ����ăX�^�b�N���x�����`�F�b�N
		bhs	recurse_ok

		lea	pathname(pc),a0
		bsr	werror_myname_and_msg
		lea	msg_dir_too_deep(pc),a0
		bsr	werror
		move.w	#2,exitcode
		bra	ls_subdir_loop

recurse_ok:
		movem.l	d1/a2-a3,-(a7)
		move.l	entry_top,-(a7)
		move.l	number_of_entry,-(a7)
		bsr	ls_onedir			*  �m�ċA�n  24 Bytes/call
		move.l	(a7)+,number_of_entry
		move.l	(a7)+,entry_top
		movem.l	(a7)+,d1/a2-a3
		bra	ls_subdir_loop

ls_subdir_dolast:
		bsr	free_list			*  ��������ȏニ�[�v���Ȃ�����A�ċA�̑O�Ƀ��X�g��free���邱�Ƃ��ł���
		bra	ls_onedir			*  �m�ċA�n   0 Bytes/call

LS_RECURSE_STACKSIZE	equ	24

ls_subdir_continue:
		cmp.l	(a2)+,d1
		bne	ls_subdir_loop
ls_subdir_return:
		bra	free_list	* rts
*****************************************************************
* add_entry - ENTRY��1�ǉ�����
*
* CALL
*      A0     �o�^���閼�O�i������MAXPATH�ȓ��ł��邱�Ɓj
*
* RETURN
*      A1     �o�^����ENTRY�\���̂̃A�h���X
*      D0.L   �j��
*****************************************************************
add_entry:
		movem.l	d1/a0/a2,-(a7)
		move.b	d0,d2
		movea.l	a0,a1
		move.l	number_of_entry,d0
		and.l	#FILELIST_UNIT-1,d0
		bne	add_entry_space_ok_1

		move.l	number_of_entry,d1
		add.l	#FILELIST_UNIT,d1
		lsl.l	#2,d1
		tst.l	entry_top
		beq	xrealloc_malloc

		move.l	d1,-(a7)
		move.l	entry_top,-(a7)
		DOS	_SETBLOCK
		addq.l	#8,a7
		tst.l	d0
		bpl	xrealloc_ok

		move.l	d1,d0
		bsr	malloc
		bmi	insufficient_memory

		move.l	d0,d1
		movea.l	d1,a0
		move.l	a1,-(a7)
		movea.l	entry_top,a1
		move.l	-8(a1),d0
		sub.l	a1,d0
		bsr	memmovi
		movea.l	(a7)+,a1
		move.l	entry_top,d0
		bsr	free
		move.l	d1,entry_top
		bra	xrealloc_ok

xrealloc_malloc:
		move.l	d1,d0
		bsr	malloc				*  ��ʂ���
		bmi	insufficient_memory

		move.l	d0,entry_top
xrealloc_ok:
		move.l	#entry_struct_size*FILELIST_UNIT,d0
		bsr	malloc_slice			*  ���ʂ���
		bmi	insufficient_memory

		movea.l	d0,a2
		movea.l	entry_top,a0
		move.l	number_of_entry,d1
		lsl.l	#2,d1
		lea	(a0,d1.l),a0
		move.l	#FILELIST_UNIT,d1
		bra	add_entry_make_newspace_continue

add_entry_make_newspace_high_loop:
		swap	d1
add_entry_make_newspace_low_loop:
		move.l	d0,(a0)+
		add.l	#entry_struct_size,d0
add_entry_make_newspace_continue:
		dbra	d1,add_entry_make_newspace_low_loop

		swap	d1
		dbra	d1,add_entry_make_newspace_high_loop

		clr.b	entry_flag(a2)
		bset.b	#FLAGBIT_ALLOC,entry_flag(a2)
		bra	add_entry_space_ok_2

add_entry_space_ok_1:
		movea.l	entry_top,a2
		move.l	number_of_entry,d0
		lsl.l	#2,d0
		movea.l	(a2,d0.l),a2
		clr.b	entry_flag(a2)
add_entry_space_ok_2:
		lea	entry_name(a2),a0
		bsr	strcpy
		clr.l	entry_linkpath(a2)
		addq.l	#1,number_of_entry
		movea.l	a2,a1
		movem.l	(a7)+,d1/a0/a2
		rts
*****************************************************************
copy_stat:
		move.b	ST_MODE(a2),entry_mode(a1)
		move.l	ST_TIME(a2),d0
		swap	d0
		move.l	d0,entry_datime(a1)
		move.l	ST_SIZE(a2),entry_size(a1)
		clr.b	entry_linkmode(a1)
		rts
*****************************************************************
set_nostat:
		move.b	#MODEVAL_DIR,entry_mode(a1)
		bset.b	#FLAGBIT_NOSTAT,entry_flag(a1)
		move.l	#OLDEST_DATIME,entry_datime(a1)
		clr.l	entry_size(a1)
		clr.l	entry_nblocks(a1)
		clr.b	entry_linkmode(a1)
		rts
*****************************************************************
lstat:
		tst.l	lndrv
		beq	stat

		movem.l	d1/a1,-(a7)
		clr.l	-(a7)
		DOS	_SUPER				*  �X�[�p�[�o�C�U�E���[�h�ɐ؂芷����
		addq.l	#4,a7
		move.l	d0,-(a7)			*  �O�� SSP �̒l
		movea.l	lndrv,a1
		movea.l	LNDRV_LINK_FILES(a1),a1
		move.w	#MODEVAL_ALL,-(a7)
		move.l	a0,-(a7)
		pea	tmp_filesbuf(pc)
		jsr	(a1)
		lea	10(a7),a7
		move.l	d0,d1
		DOS	_SUPER				*  ���[�U�E���[�h�ɖ߂�
		addq.l	#4,a7
		move.l	d1,d0
		movem.l	(a7)+,d1/a1
		rts

stat:
		move.w	#MODEVAL_ALL,-(a7)
		move.l	a0,-(a7)
		pea	tmp_filesbuf(pc)
		DOS	_FILES
		lea	10(a7),a7
		tst.l	d0
		rts
*****************************************************************
* test_link_if_necessary, do_test_link
*      - �o�^����ENTRY���V���{���b�N�E�����N�Ȃ�ΕK�v�ȏ������s��
*
* CALL
*      A0     �t�@�C���̃p�X��
*      A1     �t�@�C����o�^����ENTRY�\���̂̃A�h���X
*
* RETURN
*      A0     stat�Ƃ��č̗p�����t�@�C���̃p�X���̐擪�A�h���X
*             static �ȗ̈�Ȃ̂Œ��ӂ��邱��
*             �������Aset_nostat �����Ƃ��ɂ� 0
*****************************************************************
test_link_if_necessary:
		tst.b	replace_link
		bne	do_test_link

		tst.b	long_format
		beq	test_link_return
do_test_link:
		btst.b	#MODEBIT_LNK,entry_mode(a1)
		beq	test_link_return

		tst.l	lndrv
		beq	test_link_return

		movem.l	d1-d3/a2,-(a7)
		tst.b	long_format			*  -l, -v
		beq	chase_link_skip_malloc

		move.l	entry_size(a1),d0
		addq.l	#1,d0				*  +'\0'
		bsr	malloc_slice
		bmi	insufficient_memory

		move.l	d0,entry_linkpath(a1)
chase_link_skip_malloc:
		clr.l	-(a7)
		DOS	_SUPER				*  �X�[�p�[�o�C�U�E���[�h�ɐ؂芷����
		addq.l	#4,a7
		move.l	d0,-(a7)			*  �O�� SSP �̒l
		tst.b	long_format			*  -l, -v
		beq	chase_link_1

		movea.l	lndrv,a2
		movea.l	LNDRV_realpathcpy(a2),a2
		move.l	a0,-(a7)
		pea	chase_link_tmp_path(pc)
		jsr	(a2)
		addq.l	#8,a7
		move.l	d0,d1
		bmi	chase_link_1

		movem.l	d4-d7/a0-a1/a3-a6,-(a7)
		movea.l	lndrv,a2
		movea.l	LNDRV_O_OPEN(a2),a2
		clr.w	-(a7)
		pea	chase_link_tmp_path(pc)
		movea.l	a7,a6
		jsr	(a2)
		addq.l	#6,a7
		move.l	d0,d1
		movem.l	(a7)+,d4-d7/a0-a1/a3-a6
chase_link_1:
		movea.l	lndrv,a2
		movea.l	LNDRV_getrealpath(a2),a2
		move.l	a0,-(a7)
		pea	chase_link_tmp_path(pc)
		jsr	(a2)				*  �Q�ƃt�@�C���̃p�X���𓾂�
		addq.l	#8,a7
		move.l	d0,d2				*  D2.L : getrealpath��status
		DOS	_SUPER				*  ���[�U�E���[�h�ɖ߂�
		addq.l	#4,a7
		move.l	a0,d3
		tst.b	long_format			*  -l, -v
		beq	chase_link_readlink_done

		tst.l	d1
		bmi	chase_link_free_return

		move.l	entry_size(a1),-(a7)
		move.l	entry_linkpath(a1),-(a7)
		move.w	d1,-(a7)
		DOS	_READ
		lea	10(a7),a7
		exg	d0,d1
		move.w	d0,-(a7)
		DOS	_CLOSE
		addq.l	#2,a7
		tst.l	d1
		bmi	chase_link_free_return

		movea.l	entry_linkpath(a1),a0
		clr.b	(a0,d1.l)
chase_link_readlink_done:
		tst.b	replace_link
		bne	stat_linkref

		tst.b	mark_dirs
		bne	stat_linkref

		tst.b	long_format
		bne	test_link_done			*  �Q�ƃp�X����������Ηǂ�
stat_linkref:
		*  �Q�ƃt�@�C����stat�𓾂�
		tst.l	d2				*  getrealpath�͐����������H
		bmi	test_link_done

		sf	d2
		move.l	a1,-(a7)
		lea	chase_link_tmp_path(pc),a0
		bsr	strip_excessive_slashes
		lea	link_nameck_buffer(pc),a1
		bsr	dirnameck
		bmi	stat_linkref_name_ok

		movea.l	a1,a0
		bsr	strip_excessive_slashes
		tst.b	3(a0)
		bne	stat_linkref_name_ok

		st	d2				*  root directory
stat_linkref_name_ok:
		movea.l	(a7)+,a1
		tst.b	replace_link
		beq	get_linkref_mode

		move.l	a0,d3
		bsr	lstat
		bpl	do_replace_link

		tst.b	d2
		beq	test_link_done

		bsr	set_nostat
		bsr	test_subdir_bit
		moveq	#0,d3
		bra	chase_link_free_return

do_replace_link:
		lea	tmp_filesbuf(pc),a2
		move.b	ST_MODE(a2),d0
		btst	#MODEBIT_LNK,d0
		bne	set_linkref_mode

		bsr	copy_stat
		bra	chase_link_free_return

get_linkref_mode:
		move.w	#-1,-(a7)
		move.l	a0,-(a7)
		DOS	_CHMOD
		addq.l	#6,a7
		tst.l	d0
		bpl	set_linkref_mode

		tst.b	d2
		beq	test_link_done

		moveq	#MODEVAL_DIR,d0
set_linkref_mode:
		move.b	d0,entry_linkmode(a1)
test_link_done:
		movea.l	d3,a0
		movem.l	(a7)+,d1-d3/a2
test_link_return:
		rts

chase_link_free_return:
		tst.b	long_format
		beq	test_link_done

		move.l	entry_linkpath(a1),d0
		bsr	free
		clr.l	entry_linkpath(a1)
		bra	test_link_done
*****************************************************************
* test_subdir_bit - �o�^����ENTRY���f�B���N�g���Ȃ��SUBDIR�t���O��ON�ɂ���
*
* CALL
*      A1     �t�@�C����o�^����ENTRY�\���̂̃A�h���X
*
* RETURN
*      none
*****************************************************************
test_subdir_bit:
		btst.b	#MODEBIT_DIR,entry_mode(a1)
		beq	test_subdir_bit_ok

		bset.b	#FLAGBIT_SUBDIR,entry_flag(a1)
		addq.l	#1,number_of_subdir
test_subdir_bit_ok:
		rts
*****************************************************************
* set_cluster_size - �o�^����ENTRY�̃N���X�^�������߂ăZ�b�g����
*
* CALL
*      A0     �t�@�C���̃p�X��
*      A1     �t�@�C����o�^����ENTRY�\���̂̃A�h���X
*
* RETURN
*      D0.L   �j��
*****************************************************************
set_cluster_size:
		move.b	entry_mode(a1),d0
		btst	#MODEBIT_DIR,d0
		beq	set_cluster_size_1

		tst.b	virtual_dir_size
		beq	set_cluster_size_1

		bsr	calc_true_cluster_size

		move.l	d1,-(a7)
		move.w	entry_drive(a1),d0
		add.b	#'A'-1,d0
		move.b	d0,assign_call_buffer
		pea	assign_result_buffer(pc)
		pea	assign_call_buffer(pc)
		clr.w	-(a7)
		DOS	_ASSIGN
		lea	10(a7),a7
		move.l	d0,d1
		bmi	release_assign_done

		pea	assign_call_buffer(pc)
		move.w	#4,-(a7)
		DOS	_ASSIGN
		addq.l	#6,a7
release_assign_done:
		pea	dpbbuf(pc)
		move.w	entry_drive(a1),-(a7)
		DOS	_GETDPB
		addq.l	#6,a7
		exg	d0,d1
		tst.l	d0
		bmi	resume_assign_done

		move.w	d0,-(a7)
		pea	assign_result_buffer(pc)
		pea	assign_call_buffer(pc)
		move.w	#1,-(a7)
		DOS	_ASSIGN
		lea.l	12(a7),a7
resume_assign_done:
		tst.l	d1
		bmi	set_virtual_dir_size_done

		moveq	#0,d0
		move.w	dpbbuf+2,d0
		move.b	dpbbuf+5,d1
		lsl.l	d1,d0
		move.l	entry_nblocks(a1),d1
		bsr	mulul
		move.l	d0,entry_size(a1)
set_virtual_dir_size_done:
		move.l	(a7)+,d1
		rts

set_cluster_size_1:
		tst.b	needs_nblocks
		beq	set_cluster_size_return

		and.b	#(MODEVAL_VOL|MODEVAL_DIR),d0
		bne	calc_true_cluster_size

		move.l	entry_size(a1),d0
		move.l	#BLOCKSIZE,d1
		bsr	divul
		addq.l	#1,d0
		bra	do_set_cluster_size

calc_true_cluster_size:
		movem.l	d1-d2/a2,-(a7)
		moveq	#0,d2
		lea	fatchkbuf(pc),a2
		move.w	#2+8*FATCHK_STATIC+4,-(a7)
		move.l	a2,d0
		bset	#31,d0
		move.l	d0,-(a7)
		move.l	a0,-(a7)
		DOS	_FATCHK
		lea	10(a7),a7
		cmp.l	#EBADPARAM,d0
		bne	fatchk_success

		move.l	#65520,d0
		move.l	d0,d1
		bsr	malloc
		move.l	d0,d2
		bpl	fatchk_malloc_ok

		sub.l	#$81000000,d0
		cmp.l	#2+8*FATCHK_STATIC+4+4,d0
		blo	insufficient_memory

		move.l	d0,d1
		bsr	malloc
		move.l	d0,d2
		bmi	insufficient_memory
fatchk_malloc_ok:
		subq.w	#4,d1
		move.w	d1,-(a7)
		bset	#31,d2
		move.l	d2,-(a7)
		bclr	#31,d2
		move.l	a0,-(a7)
		DOS	_FATCHK
		lea	10(a7),a7
		cmp.l	#EBADPARAM,d0
		beq	insufficient_memory

		movea.l	d2,a2
fatchk_success:
		moveq	#0,d1
		tst.l	d0
		bmi	calc_cluster_size_done

		move.w	(a2)+,entry_drive(a1)
calc_cluster_size_loop:
		tst.l	(a2)+
		beq	calc_cluster_size_done

		add.l	(a2)+,d1
		bra	calc_cluster_size_loop

calc_cluster_size_done:
		move.l	d2,d0
		beq	cluster_size_ok

		bsr	free
cluster_size_ok:
		move.l	d1,d0
		movem.l	(a7)+,d1-d2/a2
do_set_cluster_size:
		move.l	d0,entry_nblocks(a1)
set_cluster_size_return:
		rts
*****************************************************************
* free_list - ENTRY�\���̃A�h���X�z��Ƃ��ׂĂ�ENTRY�\���̂�free����
*
* CALL
*      none
*
* RETURN
*      D0-D1/A0-A1   �j��
*****************************************************************
free_list:
		move.l	entry_top,d1
		beq	free_list_return

		movea.l	d1,a0
		move.l	number_of_entry,d1
		bra	free_list_continue

free_list_high_loop:
		swap	d1
free_list_low_loop:
		movea.l	(a0)+,a1
		move.l	entry_linkpath(a1),d0
		beq	free_list_1

		bsr	free
free_list_1:
		btst.b	#FLAGBIT_ALLOC,entry_flag(a1)
		beq	free_list_continue

		move.l	a1,d0
		bsr	free
free_list_continue:
		dbra	d1,free_list_low_loop

		swap	d1
		dbra	d1,free_list_high_loop
free_list_done:
		move.l	entry_top,d0
		bsr	free
free_list_return:
		rts
****************************************************************
* output - ENTRY�\���̂̃��X�g���o�͂���
*
* CALL
*      A0     ENTRY�\���̃A�h���X�z��̐擪�A�h���X
*      D0.L   ENTRY��
*
* RETURN
*      none
****************************************************************
output:
		movem.l	d0-d7/a0-a4,-(a7)
		movea.l	a0,a2				*  A2 : ENTRY�\���̃A�h���X�z��|�C���^
		move.l	d0,d2				*  D2.L : ENTRY��
		beq	output_return

		tst.b	long_format
		bne	output_single_column

		move.b	format,d0
		beq	output_single_column

		subq.b	#3,d0
		beq	output_inline
****************
output_multi_column:
		*
		*  �ő包�������ς� -> D1.L
		*
		moveq	#0,d1
		movem.l	d2/a2,-(a7)
multi_column_search_longest:
		movea.l	(a2)+,a3
		lea	entry_name(a3),a0
		bsr	namewidth
		cmp.l	d1,d0
		bls	multi_column_search_longest_continue

		move.l	d0,d1
multi_column_search_longest_continue:
		subq.l	#1,d2
		bne	multi_column_search_longest

		movem.l	(a7)+,d2/a2
		tst.b	print_nblocks
		beq	multi_column_calc_length_1

		addq.l	#5,d1		*  -s �ł̐��l�\��������4���Ƃ��Č��ς�D
					*  ������\���͂��邪�C�ȒP�̂��߁C�l�����Ȃ��D
multi_column_calc_length_1:
		tst.b	quote
		beq	multi_column_calc_length_2

		addq.l	#2,d1
multi_column_calc_length_2:
		addq.l	#2,d1		*  D1.L : 1���ڂ̍ő包��
		move.l	d1,-(a7)
		*
		*  D3.L <- 1�s�ɓ���ő區�ڐ� = (�s�̌��� - 1) / 1���ڂ̍ő包��
		*
		move.l	columns,d0
		subq.l	#1,d0
		bls	width_1

		bsr	divul
		move.l	d0,d3
		bne	width_ok
width_1:
		moveq	#1,d3		*  1���ڂ�����Ȃ��ꍇ�́C1���ڂ���������̂Ƃ���
width_ok:
		move.l	d2,d0		*  �G���g������
		move.l	d3,d1		*  1�s�ɓ���ő區�ڐ���
		bsr	divul		*  ����
		move.l	d0,d4		*  D4.L : �s�� = �G���g���� / 1�s�ɓ���ő區�ڐ�
		move.l	d1,d5		*  D5.L : �]��
		beq	height_ok	*             ��������΍s���m��

		addq.l	#1,d4		*  �]�肪���� ... �s���͂����1�s����
		*
		*  1�s�����Ȃ����D-x �łȂ���΁A�s�������Ƃ� 1�s�̍��ڐ����Čv�Z����D
		*
		cmpi.b	#2,format
		beq	height_ok

		move.l	d2,d0
		move.l	d4,d1
		bsr	divul
		move.l	d0,d3
		move.l	d1,d5
		beq	height_ok

		addq.l	#1,d3		*  �]�肪���� ... 1�s�̍��ڐ��͂����1���ڑ���
					*  ������ D5.L �� 1���ڑ����s��
height_ok:
		*
		*  D3.L = 1�s�̍��ڐ� != 0 ��
		*  D4.L = �s�� != 0 ���m�肵���D
		*
		*  D5.L �ɁAENTRY�\���̃A�h���X�z����X�L��������X�e�b�v��ݒ肷��D
		*
		*    -x �łȂ���΁C�s���iD4.L�j�D
		*    -x �Ȃ�C1�D
		*
		move.l	d4,d5
		cmpi.b	#2,format
		bne	step_ok

		moveq	#1,d5
step_ok:
		move.l	(a7)+,d6			*  D6.L : 1���ڂ̌���
		*
		*  �o�͊J�n
		*
		moveq	#0,d7				*  D7.L : ENTRY index
		moveq	#0,d1				*  D1.L : Y loop counter
output_multi_column_loop_y:
		movem.l	d1/d3,-(a7)
output_multi_column_loop_x:
		cmp.l	d2,d7
		bhs	output_multi_column_continue_y

		move.l	d7,d0
		lsl.l	#2,d0
		movea.l	(a2,d0.l),a3
		moveq	#0,d1				*  D1.L : column
		tst.b	print_nblocks
		beq	output_multi_column_size_ok

		move.l	entry_nblocks(a3),d0
		move.l	d3,-(a7)
		moveq	#4,d3				*  �ŏ��t�B�[���h��
		bsr	bufprint_Nu
		move.l	(a7)+,d3
		addq.l	#5,d1
output_multi_column_size_ok:
		lea	entry_name(a3),a0
		bsr	print_name
		add.l	d0,d1
		move.b	entry_mode(a3),d0
		bsr	print_mark
		add.l	d0,d1
		sub.l	d6,d1
		bhs	output_multi_column_continue_x

		neg.l	d1
		moveq	#' ',d0
		bsr	bufset
output_multi_column_continue_x:
		add.l	d5,d7
		subq.l	#1,d3
		bne	output_multi_column_loop_x
output_multi_column_continue_y:
		bsr	putline
		movem.l	(a7)+,d1/d3
		addq.l	#1,d1
		cmp.l	d4,d1
		bhs	output_return

		cmpi.b	#2,format
		beq	output_multi_column_x_ok

		move.l	d1,d7
output_multi_column_x_ok:
		bra	output_multi_column_loop_y
****************
output_single_column:
output_single_column_loop:
		subq.l	#1,d2
		bcs	output_return

		movea.l	(a2)+,a3
		tst.b	print_nblocks
		beq	output_single_column_size_ok

		move.l	entry_nblocks(a3),d0
		moveq	#4,d3				*  �ŏ��t�B�[���h��
		bsr	bufprint_Nu
output_single_column_size_ok:
		tst.b	long_format
		beq	long_format_misc_ok

		*  mode

		move.b	entry_mode(a3),d1
		bchg	#MODEBIT_RDO,d1
		moveq	#'l',d0
		btst	#MODEBIT_LNK,d1
		bne	long_format_mode_1

		moveq	#'v',d0
		btst	#MODEBIT_VOL,d1
		bne	long_format_mode_1

		moveq	#'d',d0
		btst	#MODEBIT_DIR,d1
		bne	long_format_mode_1

		moveq	#'-',d0
long_format_mode_1:
		bsr	bufout
		moveq	#'a',d0
		moveq	#MODEBIT_ARC,d3
		bsr	set_mode_char
		moveq	#'s',d0
		moveq	#MODEBIT_SYS,d3
		bsr	set_mode_char
		moveq	#'h',d0
		moveq	#MODEBIT_HID,d3
		bsr	set_mode_char
		moveq	#'r',d0
		bsr	bufout
		moveq	#'w',d0
		moveq	#MODEBIT_RDO,d3
		bsr	set_mode_char
		moveq	#'x',d0
		moveq	#MODEBIT_EXE,d3
		bsr	set_mode_char
		moveq	#' ',d0
		bsr	bufout

		*  size [byte]

		move.l	entry_size(a3),d0
		moveq	#8,d3				*  �ŏ��t�B�[���h��
		bsr	bufprint_Nu

		*  datime

		tst.b	long_datime
		bne	print_long_datime

		*  abbrev. month
		move.w	entry_date(a3),d0
		lsr.w	#5,d0
		and.w	#15,d0
		lsl.w	#2,d0
		lea	montab(pc),a0
		lea	(a0,d0.w),a1
		bsr	bufcpy
		moveq	#' ',d0
		bsr	bufout
		*  day of month
		moveq	#0,d0
		move.w	entry_date(a3),d0
		and.l	#31,d0
		moveq	#2,d3				*  �ŏ��t�B�[���h��
		bsr	bufprint_Nu
		*  hh:mm or year
		moveq	#0,d0
		btst.b	#FLAGBIT_NOSTAT,entry_flag(a3)
		bne	print_unix_date_year_1

		move.w	entry_date(a3),d0
		cmp.w	present_date,d0
		bhi	print_unix_date_year		*  �����ȍ~�̃t�@�C��

		add.l	#$0200,d0			*  +1�N�̃Q�^
		cmp.l	cutoff_date,d0
		bls	print_unix_date_year		*  6�P���O�܂ł̃t�@�C��

		*  hour
		moveq	#':',d5
		moveq	#0,d0
		move.w	entry_time(a3),d0
		lsr.w	#8,d0
		lsr.w	#3,d0
		bsr	bufprint_02u
		*  minute
		moveq	#' ',d5
		moveq	#0,d0
		move.w	entry_time(a3),d0
		lsr.w	#5,d0
		and.w	#63,d0
		bsr	bufprint_02u
		bra	long_format_misc_ok

print_unix_date_year:
		*  year
		moveq	#0,d0
		move.w	entry_date(a3),d0
		lsr.w	#8,d0
		lsr.w	#1,d0
		add.w	#1980,d0
print_unix_date_year_1:
		moveq	#5,d3				*  �ŏ��t�B�[���h��
		bsr	bufprint_Nu
		bra	long_format_misc_ok

print_long_datime:
		*  year
		moveq	#0,d0
		btst.b	#FLAGBIT_NOSTAT,entry_flag(a3)
		bne	print_long_datime_year_1

		move.w	entry_date(a3),d0
		lsr.w	#8,d0
		lsr.w	#1,d0
		add.w	#1980,d0
print_long_datime_year_1:
		moveq	#'-',d5
		bsr	bufprint_04u
		*  month
		move.w	entry_date(a3),d0
		lsr.w	#5,d0
		and.w	#15,d0
		bsr	bufprint_02u
		*  day of month
		moveq	#' ',d5
		moveq	#0,d0
		move.w	entry_date(a3),d0
		and.l	#31,d0
		bsr	bufprint_02u
		*  hour
		moveq	#':',d5
		moveq	#0,d0
		move.w	entry_time(a3),d0
		lsr.w	#8,d0
		lsr.w	#3,d0
		bsr	bufprint_02u
		*  minute
		moveq	#0,d0
		move.w	entry_time(a3),d0
		lsr.w	#5,d0
		and.w	#63,d0
		bsr	bufprint_02u
		*  second
		moveq	#' ',d5
		moveq	#0,d0
		move.w	entry_time(a3),d0
		and.w	#31,d0
		lsl.w	#1,d0
		bsr	bufprint_02u
long_format_misc_ok:
		lea	entry_name(a3),a0
		bsr	print_name
		move.b	entry_mode(a3),d0
		move.l	entry_linkpath(a3),d1
		beq	long_format_link_ok

		lea	str_arrow(pc),a1
		bsr	bufcpy
		movea.l	d1,a0
		bsr	print_name
		move.b	entry_linkmode(a3),d0
long_format_link_ok:
		bsr	print_mark
		bsr	putline
		bra	output_single_column_loop

set_mode_char:
		btst	d3,d1
		bne	bufout

		moveq	#'-',d0
		bra	bufout
****************
output_inline:
		moveq	#0,d3				*  D3.L : column
output_inline_loop:
		subq.l	#1,d2
		movea.l	(a2)+,a3
		tst.l	d3
		beq	do_output_inline

		lea	entry_name(a3),a0
		bsr	namewidth
		tst.b	quote
		beq	output_inline_1

		addq.l	#2,d0
output_inline_1:
		tst.b	print_nblocks
		beq	output_inline_2

		addq.l	#5,d0		*  -s �ł̐��l�\��������4���Ƃ��Č��ς�D
					*  ������\���͂��邪�C�ȒP�̂��߁C�l�����Ȃ��D
output_inline_2:
		tst.l	d2
		beq	output_inline_3

		addq.l	#2,d0		*  ', '�̕�
output_inline_3:
		addq.l	#1,d0		*  �^�C�v�E�}�[�N1������
					*  �t���Ȃ��\���͂��邪�C�ȒP�̂��߁C�l�����Ȃ��D

		add.l	d3,d0
		cmp.l	columns,d0
		blt	do_output_inline

		bsr	putline
		moveq	#0,d3
do_output_inline:
		moveq	#0,d1
		tst.b	print_nblocks
		beq	output_inline_size_ok

		move.l	entry_nblocks(a3),d0
		movem.l	d2-d3,-(a7)
		moveq	#1,d3				*  �ŏ��t�B�[���h��
		moveq	#1,d4				*  ���Ȃ��Ƃ��o�͂��鐔���̌���
		lea	utoa(pc),a0			*  convert procedure
		bsr	bufprintfu
		movem.l	(a7)+,d2-d3
		add.l	d0,d3
		moveq	#' ',d0
		bsr	bufout
		addq.l	#1,d3
output_inline_size_ok:
		lea	entry_name(a3),a0
		bsr	print_name
		add.l	d0,d3
		move.b	entry_mode(a3),d0
		bsr	print_mark
		add.l	d0,d3
		tst.l	d2
		beq	output_inline_done

		moveq	#',',d0
		bsr	bufout
		moveq	#' ',d0
		bsr	bufout
		addq.l	#2,d3
		bra	output_inline_loop

output_inline_done:
		bsr	putline
****************
output_return:
		movem.l	(a7)+,d0-d7/a0-a4
		rts
****************
bufprint_Nu:
		movem.l	d2-d5/a0,-(a7)
		moveq	#' ',d5
		moveq	#' ',d2				*  pad����
		moveq	#1,d4				*  ���Ȃ��Ƃ��o�͂��鐔���̌���
bufprint_Nu_2:
		lea	utoa(pc),a0			*  convert procedure
		bsr	bufprintfu
		move.b	d5,d0
		movem.l	(a7)+,d2-d5/a0
		bra	bufout

bufprint_02u:
		movem.l	d2-d5/a0,-(a7)
		moveq	#2,d4				*  ���Ȃ��Ƃ��o�͂��鐔���̌���
bufprint_0Nu:
		move.l	d4,d3				*  �ŏ��t�B�[���h��
		moveq	#'0',d2				*  pad����
		bra	bufprint_Nu_2

bufprint_04u:
		movem.l	d2-d5/a0,-(a7)
		moveq	#4,d4
		bra	bufprint_0Nu
****************************************************************
* print_name - �t�@�C�������o�͂���
*
* CALL
*      A0     �t�@�C����
*
* RETURN
*      D0.L   �o�͂�������
****************************************************************
print_name:
		movem.l	d1-d4/a0-a1,-(a7)
		movea.l	a0,a1
		moveq	#0,d1
		bsr	doquote
print_name_loop:
		moveq	#0,d0
		move.b	(a1)+,d0
		beq	print_name_done

		bsr	issjis
		bne	print_name_not_sjis

		bsr	bufout
		bsr	sjiswidth
		add.l	d0,d1

		move.b	(a1)+,d0
		beq	print_name_done

		bsr	bufout
		bra	print_name_loop

print_name_not_sjis:
		cmp.b	#$21,d0
		blo	print_name_not_graph

		cmp.b	#$7e,d0
		bls	print_name_graph

		cmp.b	#$a1,d0
		blo	print_name_not_graph

		cmp.b	#$df,d0
		bls	print_name_graph
print_name_not_graph:
		move.b	escape,d2
		subq.b	#1,d2
		blo	print_name_graph
		beq	print_name_question

		move.l	d0,d2
		moveq	#'\',d0
		bsr	bufout
		move.l	d2,d0
		addq.l	#1,d1
		moveq	#'0',d2				*  pad����
		moveq	#3,d3				*  �ŏ��t�B�[���h��
		moveq	#3,d4				*  ���Ȃ��Ƃ��o�͂��鐔���̌���
		lea	utoao(pc),a0			*  convert procedure
		bsr	bufprintfu
		add.l	d0,d1
		bra	print_name_loop

print_name_question:
		moveq	#'?',d0
print_name_graph:
		bsr	bufout
		addq.l	#1,d1
		bra	print_name_loop

print_name_done:
		bsr	doquote
		move.l	d1,d0
		movem.l	(a7)+,d1-d4/a0-a1
		rts

doquote:
		tst.b	quote
		beq	doquote_return

		moveq	#'"',d0
		bsr	bufout
		addq.l	#1,d1
doquote_return:
		rts
****************************************************************
* print_mark - /*@�}�[�N���o�͂���
*
* CALL
*      A0     �t�@�C����
*      D0.B   mode
*
* RETURN
*      D0.L   �o�͂�������
****************************************************************
print_mark:
		movem.l	d1-d2/a1,-(a7)
		move.b	d0,d1
		btst	#MODEBIT_LNK,d1
		beq	print_mark_not_link

		tst.b	mark_dirs
		beq	print_mark_return_0

		moveq	#'@',d2
		bra	print_mark_add_return

print_mark_not_link:
		tst.b	mark_dirs
		beq	print_mark_return_0

		moveq	#'/',d2
		btst	#MODEBIT_DIR,d1
		bne	print_mark_add_return

		tst.b	mark_exes
		beq	print_mark_return_0

		moveq	#'*',d2
		btst	#MODEBIT_EXE,d1
		bne	print_mark_add_return

		bsr	strlen
		moveq	#2,d1
		lea	str_dotX(pc),a1
		bsr	tailmatch
		beq	print_mark_add_return

		lea	str_dotR(pc),a1
		bsr	tailmatch
		bne	print_mark_return_0
print_mark_add_return:
		move.b	d2,d0
		bsr	bufout
		moveq	#1,d0
		bra	print_mark_return

print_mark_return_0:
		moveq	#0,d0
print_mark_return:
		movem.l	(a7)+,d1-d2/a1
		rts
****************************************************************
bufprintfu:
		movem.l	d1/a1-a2,-(a7)
		moveq	#0,d1				*  �E�l��
		lea	bufout(pc),a1			*  output procedure
		suba.l	a2,a2
		bsr	printfi
		movem.l	(a7)+,d1/a1-a2
		rts
****************************************************************
bufout:
		tst.l	_buf_remain
		bne	_bufout_1

		bsr	flush_buffer
_bufout_1:
		move.l	a0,-(a7)
		movea.l	_bufp,a0
		move.b	d0,(a0)+
		move.l	a0,_bufp
		movea.l	(a7)+,a0
		sub.l	#1,_buf_remain
		rts
****************************************************************
bufcpy:
		movem.l	d0-d1/a0-a1,-(a7)
		movea.l	a1,a0
		bsr	strlen
		move.l	d0,d1
		beq	bufcpy_return
bufcpy_loop0:
		movea.l	_bufp,a0
bufcpy_loop:
		move.l	_buf_remain,d0
		bne	bufcpy_1

		move.l	a0,_bufp
		bsr	flush_buffer
		bra	bufcpy_loop0

bufcpy_1:
		cmp.l	d1,d0
		bls	bufcpy_2

		move.l	d1,d0
bufcpy_2:
		bsr	memmovi
		sub.l	d0,_buf_remain
		sub.l	d0,d1
		bne	bufcpy_loop

		move.l	a0,_bufp
bufcpy_return:
		movem.l	(a7)+,d0-d1/a0-a1
		rts
****************************************************************
bufset:
		movem.l	d1-d2/a0,-(a7)
		move.l	d1,d2
		beq	bufset_return
bufset_loop0:
		movea.l	_bufp,a0
bufset_loop:
		move.l	_buf_remain,d1
		bne	bufset_1

		move.l	a0,_bufp
		bsr	flush_buffer
		bra	bufset_loop0

bufset_1:
		cmp.l	d2,d1
		bls	bufset_2

		move.l	d2,d1
bufset_2:
		bsr	memset
		adda.l	d1,a0
		sub.l	d1,_buf_remain
		sub.l	d1,d2
		bne	bufset_loop

		move.l	a0,_bufp
bufset_return:
		movem.l	(a7)+,d1-d2/a0
		rts
****************************************************************
* putline - �o�b�t�@�s�i_linebuf�`_bufp�j���o�͂���
*
* CALL
*      none
*
* RETURN
*      none
****************************************************************
putline:
		cmp.l	#2,_buf_remain
		bhs	putline_1

		bsr	flush_buffer
putline_1:
		move.l	a0,-(a7)
		movea.l	_bufp,a0
		move.b	#CR,(a0)+
		move.b	#LF,(a0)+
		move.l	a0,_bufp
		movea.l	(a7)+,a0
		bsr	flush_buffer
		rts
****************************************************************
flush_buffer:
		movem.l	d0/a0,-(a7)
		lea	_linebuf(pc),a0
		move.l	_bufp,d0
		sub.l	a0,d0
		move.l	d0,-(a7)
		move.l	a0,-(a7)
		move.w	#1,-(a7)
		DOS	_WRITE
		lea	10(a7),a7
		move.l	a0,_bufp
		move.l	#LINEBUFSIZE,_buf_remain
		movem.l	(a7)+,d0/a0
		rts
****************************************************************
* namewidth - ������̌���
*
* CALL
*      A0     ������̐擪�A�h���X
*
* RETURN
*      D0.L   ����
****************************************************************
namewidth:
		movem.l	d1/a0,-(a7)
		moveq	#0,d1
namewidth_loop:
		move.b	(a0)+,d0
		beq	namewidth_done

		bsr	issjis
		beq	namewidth_sjis

		cmp.b	#$21,d0
		blo	namewidth_nongraph

		cmp.b	#$7e,d0
		bls	namewidth_1

		cmp.b	#$a1,d0
		blo	namewidth_nongraph

		cmp.b	#$df,d0
		bls	namewidth_1
namewidth_nongraph:
		move.b	escape,d0
		subq.b	#2,d0
		bne	namewidth_1

		addq.l	#4,d1
		bra	namewidth_loop

namewidth_1:
		addq.l	#1,d1
		bra	namewidth_loop

namewidth_sjis:
		bsr	sjiswidth
		add.l	d0,d1
		tst.b	(a0)
		beq	namewidth_done

		addq.l	#1,a0
		bra	namewidth_loop

namewidth_done:
		move.l	d1,d0
		movem.l	(a7)+,d1/a0
		rts
****************************************************************
* sjiswidth - �V�t�gJIS�����̌���
*
* CALL
*      D0.B   �V�t�gJIS�����̑�1�o�C�g
*
* RETURN
*      D0.L   ����
****************************************************************
sjiswidth:
		cmp.b	#$80,d0
		beq	sjiswidth_1

		cmp.b	#$f0,d0
		bhs	sjiswidth_1

		moveq	#2,d0
		rts

sjiswidth_1:
		moveq	#1,d0
		rts
****************************************************************
* cmp_name, cmp_extention, cmp_time, cmp_size - sort�p�̔�r���[�`��
*
* CALL
*      A0, A1   ENTRY�\���̂̃A�h���X
*
* RETURN
*      CCR      ��r����
*      D0.L     �j��
****************************************************************
cmp_time:
		move.l	entry_datime(a1),d0
		sub.l	entry_datime(a0),d0
		beq	cmp_name
		rts

cmp_size:
		move.l	entry_size(a1),d0
		sub.l	entry_size(a0),d0
		beq	cmp_name
		rts

cmp_extention:
		movem.l	a0-a1,-(a7)
		bsr	suffix2
		exg	a0,a1
		bsr	suffix2
		exg	a0,a1
		tst.b	case_insensitive
		beq	cmp_extention_cs

		bsr	stricmp
		movem.l	(a7)+,a0-a1
		beq	cmp_name
		rts

cmp_extention_cs:
		bsr	cmp_name
		movem.l	(a7)+,a0-a1
		beq	cmp_name
		rts

cmp_name:
		tst.b	case_insensitive
		beq	strcmp

		bsr	stricmp
		beq	strcmp
		rts
*****************************************************************
* sort - ENTRY�\���̂��\�[�g����i�q�[�v�E�\�[�g�j
*
* CALL
*      A0     ENTRY�\���̃A�h���X�z��̐擪�A�h���X
*      D0.L   �v�f��
*
* RETURN
*      none
*****************************************************************
sort:
		movem.l	d0-d5/a0-a6,-(a7)
		move.l	cmp_func,d1
		beq	sort_done

		movea.l	d1,a2				*  A2 : ��r���[�`���̃G���g���E�A�h���X
		movea.l	a0,a3
		move.l	d0,d3
		move.l	d0,d2
		lsr.l	#1,d2
		move.l	d2,d0
		lsl.l	#2,d0
		lea	(a3,d0.l),a6
sort_loop_1:
		cmp.l	#1,d2
		blo	sort_2

		move.l	-(a6),d4
		bsr	sort_add_to_heap
		subq.l	#1,d2
		bra	sort_loop_1

sort_2:
		moveq	#1,d2
		move.l	d3,d0
		lsl.l	#2,d0
		lea	(a3,d0.l),a6
sort_loop_2:
		subq.l	#1,d3
		bls	sort_done

		move.l	-(a6),d4
		move.l	(a3),(a6)
		bsr	sort_add_to_heap
		bra	sort_loop_2

sort_done:
		movem.l	(a7)+,d0-d5/a0-a6
		rts

sort_add_to_heap:
		move.l	d2,d1
sort_add_to_heap_loop:
		move.l	d1,d0
		lsl.l	#2,d0
		lea	-4(a3,d0.l),a4
		add.l	d1,d1
		cmp.l	d3,d1
		bhi	sort_add_to_heap_loop_break
		blo	sort_add_to_heap_1

		move.l	d1,d0
		lsl.l	#2,d0
		movea.l	-4(a3,d0.l),a0
		bra	sort_add_to_heap_2

sort_add_to_heap_1:
		move.l	d1,d0
		lsl.l	#2,d0
		lea	-4(a3,d0.l),a5
		movea.l	(a5)+,a0
		movea.l	(a5),a1
		bsr	comp
		beq	sort_add_to_heap_2

		addq.l	#1,d1
		movea.l	a1,a0
sort_add_to_heap_2:
		movea.l	d4,a1
		bsr	comp
		bne	sort_add_to_heap_loop_break

		move.l	a0,(a4)
		bra	sort_add_to_heap_loop

sort_add_to_heap_loop_break:
		move.l	d4,(a4)
		rts

comp:
		tst.b	gather
		beq	comp_1

		move.b	entry_mode(a1),d0
		move.b	entry_mode(a0),d5
		eor.b	d5,d0
		and.b	#MODEVAL_DIR,d0
		beq	comp_1

		and.b	#MODEVAL_DIR,d5
		rts

comp_1:
		jsr	(a2)
		slt	d0
		tst.b	reverse
		bne	comp_reverse

		tst.b	d0
		rts

comp_reverse:
		not.b	d0
		rts
****************************************************************
* suffix2 - �t�@�C�����̊g���q���̃A�h���X
*
* CALL
*      A0     �t�@�C�����̐擪�A�h���X
*
* RETURN
*      A0     �g���q���̃A�h���X�i�e.�f�̈ʒu�D�e.�f��������΍Ō�� NUL ���w���j
*      CCR    TST.B (A0)
*
* NOTE
*      have_to_headtail �� 0 �łȂ���΁Cheadtail���Ă��tail������X�L��������D
*      tail���̐擪�� . �̘A���̓X�L�b�v����D
*****************************************************************
suffix2:
		tst.b	have_to_headtail
		beq	suffix2_skip_first_period

		move.l	a1,-(a7)
		bsr	headtail
		movea.l	a1,a0
		movea.l	(a7)+,a1
suffix2_skip_first_period:
		cmpi.b	#'.',(a0)+
		beq	suffix2_skip_first_period

		subq.l	#1,a0
		bra	suffix
****************************************************************
* is_reldir - ���O�� . �� .. �ł��邩�ǂ����𒲂ׂ�
*
* CALL
*      A0     ���O
*
* RETURN
*      D0.L   ���O�� . �� .. �Ȃ�� 1�C�����Ȃ��� 0
****************************************************************
is_reldir:
		moveq	#0,d0
		cmpi.b	#'.',(a0)
		bne	is_reldir_return

		tst.b	1(a0)
		beq	is_reldir_return_true

		cmpi.b	#'.',1(a0)
		bne	is_reldir_return

		tst.b	2(a0)
		bne	is_reldir_return
is_reldir_return_true:
		moveq	#1,d0
is_reldir_return:
		rts
****************************************************************
* tailmatch - ������̖������p�^�[���ƈ�v���邩�ǂ������ׂ�
*
* CALL
*      A0     ������
*      A1     �p�^�[��
*      D0.L   ������̒���
*      D1.L   �p�^�[���̒���
*
* RETURN
*      CCR    �}�b�`����� EQ�C�����Ȃ��� NE�D
****************************************************************
tailmatch:
		movem.l	d0-d1/a0,-(a7)
		sub.l	d1,d0
		bcs	tailmatch_return

		adda.l	d0,a0
		bsr	stricmp
tailmatch_return:
		movem.l	(a7)+,d0-d1/a0
		rts
*****************************************************************
malloc:
		move.l	d0,-(a7)
		DOS	_MALLOC
		addq.l	#4,a7
		tst.l	d0
		rts
*****************************************************************
malloc_slice:
		move.l	d0,-(a7)
		move.w	#2,-(a7)
		DOS	_MALLOC2
		addq.l	#6,a7
		tst.l	d0
		rts
*****************************************************************
free:
		move.l	d0,-(a7)
		DOS	_MFREE
		addq.l	#4,a7
		rts
*****************************************************************
is_chrdev:
		move.w	d0,-(a7)
		clr.w	-(a7)
		DOS	_IOCTRL
		addq.l	#4,a7
		tst.l	d0
		bpl	is_chrdev_1

		moveq	#0,d0
is_chrdev_1:
		btst	#7,d0
		rts
*****************************************************************
dirnameck:
		move.l	a1,-(a7)
		move.l	a0,-(a7)
		DOS	_NAMECK
		addq.l	#8,a7
		tst.l	d0
		bmi	dirnameck_return

		moveq	#-1,d0
		tst.b	67(a1)
		bne	dirnameck_return

		moveq	#0,d0
dirnameck_return:
		tst.l	d0
		rts
*****************************************************************
werror_myname_and_msg:
		move.l	a0,-(a7)
		lea	msg_myname(pc),a0
		bsr	werror
		movea.l	(a7)+,a0
werror:
		move.l	d0,-(a7)
		bsr	strlen
		move.l	d0,-(a7)
		move.l	a0,-(a7)
		move.w	#2,-(a7)
		DOS	_WRITE
		lea	10(a7),a7
		move.l	(a7)+,d0
		rts
*****************************************************************
too_long_path:
		bsr	werror_myname_and_msg
		move.l	a0,-(a7)
		lea	msg_too_long_path(pc),a0
		bsr	werror
		movea.l	(a7)+,a0
		move.w	#2,exitcode
		rts
*****************************************************************
.data

	dc.b	0
	dc.b	'## ls 1.3 ##  Copyright(C)1992-93 by Itagaki Fumihiko',0

**
**  �萔
**
montab:
	dc.b	'  0',0
	dc.b	'Jan',0
	dc.b	'Feb',0
	dc.b	'Mar',0
	dc.b	'Apr',0
	dc.b	'May',0
	dc.b	'Jun',0
	dc.b	'Jul',0
	dc.b	'Aug',0
	dc.b	'Sep',0
	dc.b	'Oct',0
	dc.b	'Nov',0
	dc.b	'Dec',0
	dc.b	' 13',0
	dc.b	' 14',0
	dc.b	' 15',0

msg_myname:			dc.b	'ls: ',0
msg_dos_version_mismatch:	dc.b	'�o�[�W����2.00�ȍ~��Human68k���K�v�ł�',CR,LF,0
msg_too_long_path:		dc.b	': �p�X�������߂��܂�',CR,LF,0
msg_nofile:			dc.b	': ���̂悤�ȃt�@�C����f�B���N�g���͂���܂���',CR,LF,0
msg_dir_too_deep:		dc.b	': �f�B���N�g�����[�߂��ď����ł��܂���',CR,LF,0
msg_no_memory:			dc.b	'������������܂���',CR,LF,0
msg_illegal_option:		dc.b	'�s���ȃI�v�V���� -- ',0
msg_bad_arg:			dc.b	'����������������܂���',0
msg_bad_width:			dc.b	'���̎w�肪����������܂���',0
msg_too_few_args:		dc.b	'����������܂���',0
msg_usage:			dc.b	CR,LF
				dc.b	'�g�p�@:  ls [-1ABCDFGLQRSUVXabdeflmpqrstvx] [-w <��>] [--] [<�t�@�C��>] ...'
str_newline:			dc.b	CR,LF,0
default_arg:			dc.b	'.',0
str_dotX:			dc.b	'.X',0
str_dotR:			dc.b	'.R',0
str_dotBAK:			dc.b	'.BAK',0
str_tilde:			dc.b	'~',0
str_dos_allfile:		dc.b	'*.*',0
str_total:			dc.b	'total ',0
str_arrow:			dc.b	' -> ',0
word_COLUMNS:			dc.b	'COLUMNS',0

assign_call_buffer:		dc.b	'?:',0
**
**  �ϐ�
**
.even
long_format:		dc.b	0	*  -l
long_datime:		dc.b	0	*  -v
exploration:		dc.b	0	*  -e
recurse:		dc.b	0	*  -R
escape:			dc.b	0	*  -qb
quote:			dc.b	0	*  -Q
replace_link:		dc.b	0	*  -L
directory:		dc.b	0	*  -d
fast:			dc.b	0	*  -f
reverse:		dc.b	0	*  -r
gather:			dc.b	0	*  -G
case_insensitive:	dc.b	0	*  -D
print_nblocks:		dc.b	0	*  -s
mark_dirs:		dc.b	0	*  -p
mark_exes:		dc.b	0	*  -F
show_almost_all:	dc.b	0	*  -Aa
show_all:		dc.b	0	*  -a
not_show_backfiles:	dc.b	0	*  -B
virtual_dir_size:	dc.b	0	*  -V
*****************************************************************
.bss

.even
lndrv:			ds.l	1
columns:		ds.l	1
cmp_func:		ds.l	1	*  -USXt
entry_top:		ds.l	1
number_of_entry:	ds.l	1
number_of_subdir:	ds.l	1
_bufp:			ds.l	1
_buf_remain:		ds.l	1
cutoff_date:		ds.l	1
present_date:		ds.w	1
exitcode:		ds.w	1
format:			ds.b	1	*  -1lCxm
needs_dots_stat:	ds.b	1
needs_nblocks:		ds.b	1
print_dirheader:	ds.b	1
have_to_headtail:	ds.b	1
slash:			ds.b	1
itoabuf:		ds.b	12
.even
filesbuf:		ds.b	STATBUFSIZE
.even
tmp_filesbuf:		ds.b	STATBUFSIZE
.even
dpbbuf:			ds.b	94
assign_result_buffer:	ds.b	128
nameck_buffer:		ds.b	91
link_nameck_buffer:	ds.b	91
pathname:		ds.b	MAXPATH+1
chase_link_tmp_path:	ds.b	128
_linebuf:		ds.b	LINEBUFSIZE
.even
fatchkbuf:		ds.b	2+8*FATCHK_STATIC+4
.even

		ds.b	16384
		*  �}�[�W���ƃX�[�p�[�o�C�U�E�X�^�b�N�Ƃ����˂�16KB�m�ۂ��Ă����D
stack_lower:
		ds.b	LS_RECURSE_STACKSIZE*(MAXRECURSE+1)
		*  �K�v�ȃX�^�b�N�ʂ́C�ċA�̓x�ɏ�����X�^�b�N�ʂƂ��̉񐔂ƂŌ��܂�D
		ds.b	16
.even
stack_bottom:
*****************************************************************

.end start
