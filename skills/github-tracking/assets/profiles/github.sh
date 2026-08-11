# shellcheck shell=bash
# GitHub profile for tracker.sh. Sourced, never executed.
#
# It supplies the tracker knowledge the engine deliberately lacks: which command
# to run, how to read its output, and how to map its failures onto the shared
# exit taxonomy.
#
# Every value and function below is read by tracker.sh after it sources this
# file. Linted standalone, shellcheck cannot see that use.
#
# ripgrep applies the contents of RIPGREP_CONFIG_PATH as arguments ahead of the
# ones passed below, so a personal ripgreprc would otherwise choose what this
# profile reads out of `gh` output -- including whether an issue counts as
# blocked. Repeated here rather than left to tracker.sh because a sourced file
# that depends on its caller having done this is a footgun for the next engine.
unset RIPGREP_CONFIG_PATH

# shellcheck disable=SC2034

PROFILE_DECLARES="view:implemented
target_url:implemented
comment_list:implemented
label_history:implemented
search:implemented
create:implemented
label_edit:implemented
label_ensure:implemented
comment_add:implemented
state_set:implemented
link_parent:implemented
link_blocks:implemented"

# Validates rather than echoes. A die inside $(github_target) would exit only
# the command substitution's subshell, letting an empty target reach gh and be
# misclassified as a transport failure.
# gh writes non-fatal material to stderr while exiting 0, so merging the streams
# turns a release-update notice into the payload. GH_OUT is the value; GH_ERR is
# read only to build a failure message.
github_err_file=''
GH_OUT=''
GH_ERR=''
github_run() { # gh-args...
	local status=0
	[[ -n $github_err_file ]] || {
		github_err_file=$(mktemp)
		trap 'rm -f -- "$github_err_file"' EXIT
	}
	GH_OUT=$(gh "$@" 2>"$github_err_file") || status=$?
	GH_ERR=$(cat "$github_err_file")
	return "$status"
}

# For the paths whose only failure handling is "classify and die". The write
# paths that must report partial instead call github_run directly.
github_run_checked() { # gh-args...
	github_run "$@" || github_die "$GH_ERR"
}

github_require_target() {
	[[ -n ${TRACKER_TARGET:-} ]] ||
		die "$EXIT_USAGE" usage 'operation needs --target OWNER/NAME'
}

# Every issue selector becomes a gh argument, and label-history and link-parent
# splice it into a REST path segment. Callers compose these from issue
# references read out of issue bodies and comments, which any account can write.
# One guard rather than a check per call site, so the contract suite can assert
# its use by reading the profile's own declarations: an operation added later
# that takes a selector and forgets it fails the suite.
github_require_id() { # id name
	[[ $1 =~ ^[0-9]+$ ]] ||
		die "$EXIT_USAGE" usage "$2 must be an issue number: $1"
}

# gh does not expose a machine-readable failure class, so classification is by
# message. An unmatched failure is transport, the class whose contract is "the
# caller decides whether to retry" — never the engine.
# Emits "<exit-code> <class>" so the JSON error object's class always agrees
# with the exit code. Passing a hardcoded class alongside a computed code is how
# a 401 comes to report itself as a transport failure.
github_classify() {
	local output=$1 lowered
	# gh emits "Not Found (HTTP 404)" from the REST paths and "Could not resolve
	# to an issue" from the GraphQL ones. Matching case-sensitively caught only
	# the second, so a permanently-missing object reported as retryable.
	lowered=$(printf '%s' "$output" | LC_ALL=C tr '[:upper:]' '[:lower:]')
	case $lowered in
	*'could not resolve'* | *'not found'* | *'no such'* | *'http 404'*)
		printf '%s %s' "$EXIT_NOT_FOUND" not-found
		;;
	*'authentication'* | *'http 401'* | *'http 403'* | *'gh auth login'*)
		printf '%s %s' "$EXIT_AUTH" auth
		;;
	*) printf '%s %s' "$EXIT_TRANSPORT" transport ;;
	esac
}

# Single exit path for a failed gh call, so code and class cannot disagree.
github_die() {
	local output=$1 code class
	read -r code class <<<"$(github_classify "$output")"
	die "$code" "$class" "$output"
}

profile_target_url() {
	github_require_target
	local out url
	github_run_checked repo view "$TRACKER_TARGET" --json url --jq .url
	out=$GH_OUT
	url=${out%/}
	printf '%s\n' "$url"
}

profile_view() {
	github_require_target
	(($# >= 1)) || die "$EXIT_USAGE" usage 'view needs an issue id'
	local id=$1 out
	github_require_id "$id" 'issue id'
	github_run_checked issue view "$id" --repo "$TRACKER_TARGET" \
		--json number,title,body,labels,parent,state,url,updatedAt
	out=$GH_OUT
	# Validate the source shape before normalizing. The jq below indexes
	# .parent.number and .labels[].name; a payload carrying "parent":"bad" or
	# "labels":["bad"] would crash it and surface as a transport error rather
	# than the malformed-payload error a caller can act on.
	jq -e '
		type == "object"
		and (.number | type == "number")
		and (.title | type == "string")
		and (.body | type == "string")
		and (.labels | type == "array")
		and all(.labels[]; type == "object" and (.name | type == "string"))
		and (.url | type == "string")
		and ((.parent == null) or
			((.parent | type == "object") and (.parent.number | type == "number")))
	' >/dev/null 2>&1 <<<"$out" ||
		die "$EXIT_TRANSPORT" transport \
			'read-back returned malformed or incomplete JSON'
	jq '{
		id: (.number | tostring),
		ref: ("#" + (.number | tostring)),
		url: .url,
		title: .title,
		body: .body,
		labels: [.labels[].name],
		state: (.state | ascii_downcase),
		done: ((.state | ascii_downcase) == "closed"),
		parent: (if .parent == null then null else (.parent.number | tostring) end),
		updated: (.updatedAt // null)
	}' <<<"$out"
}

profile_comment_list() {
	github_require_target
	(($# >= 1)) || die "$EXIT_USAGE" usage 'comment-list needs an issue id'
	local id=$1 out
	github_require_id "$id" 'issue id'
	github_run_checked issue view "$id" --repo "$TRACKER_TARGET" --json comments
	out=$GH_OUT
	jq -e '(.comments | type == "array")
		and all(.comments[]; type == "object" and (.body | type == "string"))' \
		>/dev/null 2>&1 <<<"$out" ||
		die "$EXIT_TRANSPORT" transport \
			'read-back returned malformed or incomplete JSON'
	jq '[.comments[].body]' <<<"$out"
}

# Enumerated, not the ranges [A-Za-z0-9._:/-] and [A-Za-z0-9._:/ -]: a bash
# bracket expression takes its ranges from the locale's collation, so under a
# territory UTF-8 locale -- the ordinary interactive setting -- [A-Za-z] admits
# accented letters, and `statusé` reached the jq splice below through a guard
# whose comment says it restricts the label to the characters GitHub labels use.
# tracker.sh's profile-name check spells its set out for the same reason.
# Pinning the collation instead would mean an `LC_ALL=C` subshell around the
# match, since a variable assignment cannot prefix the `[[` builtin. Do not
# "simplify" these back to ranges; tests/fixtures/github-tracking/tracker-test.sh
# fails if you do.
# The two differ by exactly one character: the space, which a label may contain
# but cannot begin with.
github_label_first='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._:/-'
github_label_rest='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._:/ -'
readonly github_label_first github_label_rest

# GitHub exposes a label timeline. A tracker without one declares label_history
# degraded to "unknown" rather than guessing, which the tracking conventions
# already define a behavior for.
profile_label_history() {
	github_require_target
	(($# >= 2)) || die "$EXIT_USAGE" usage 'label-history needs an issue id and a label'
	local id=$1 label=$2 out
	github_require_id "$id" 'issue id'
	# The label is spliced into a jq program below, so restrict it to the
	# character set GitHub labels actually use rather than escaping ad hoc.
	[[ $label =~ ^[$github_label_first][$github_label_rest]*$ ]] ||
		die "$EXIT_USAGE" usage "label cannot be queried safely: $label"
	# --slurp aggregates pages before filtering. Without it gh applies --jq to
	# each page separately and a paginated timeline yields one line per page.
	github_run_checked api "repos/$TRACKER_TARGET/issues/$id/timeline" --paginate --slurp \
		--jq "[.[][] | select(.event==\"labeled\" and .label.name==\"$label\")] | last | .created_at // \"unknown\""
	out=$GH_OUT
	[[ -n $out && $out != null ]] || out=unknown
	printf '%s\n' "$out"
}

# Named predicates, not an opaque query string: a query string is
# tracker-native, so accepting one would leave a per-tracker branch in every
# calling skill.
profile_search() {
	github_require_target
	local state=open text='' label='' parent='' updated_before='' query out
	while (($#)); do
		case $1 in
		--state)
			(($# >= 2)) || die "$EXIT_USAGE" usage '--state needs a value'
			state=$2
			shift 2
			;;
		--text)
			(($# >= 2)) || die "$EXIT_USAGE" usage '--text needs a value'
			text=$2
			shift 2
			;;
		--label)
			(($# >= 2)) || die "$EXIT_USAGE" usage '--label needs a value'
			label=$2
			shift 2
			;;
		--parent)
			(($# >= 2)) || die "$EXIT_USAGE" usage '--parent needs a value'
			parent=$2
			shift 2
			;;
		--updated-before)
			(($# >= 2)) || die "$EXIT_USAGE" usage '--updated-before needs a value'
			updated_before=$2
			shift 2
			;;
		*) die "$EXIT_USAGE" usage "unknown search predicate: $1" ;;
		esac
	done
	# Every value is quoted, not just --text: GitHub ORs multiple repo:
	# qualifiers, so one unquoted predicate carrying "repo:other/private"
	# widens the search past --target and returns issues from another repo.
	local value
	for value in "$state" "$label" "$parent" "$updated_before" "$text"; do
		[[ $value != *'"'* ]] ||
			die "$EXIT_USAGE" usage 'search values cannot contain a double quote'
	done
	case $state in
	open | closed | any) ;;
	*) die "$EXIT_USAGE" usage "state must be open, closed or any: $state" ;;
	esac
	query="repo:$TRACKER_TARGET"
	[[ $state == any ]] || query="$query state:$state"
	[[ -z $label ]] || query="$query label:\"$label\""
	[[ -z $parent ]] || query="$query parent-issue:\"$parent\""
	[[ -z $updated_before ]] || query="$query updated:<\"$updated_before\""
	[[ -z $text ]] || query="$query \"$text\""
	github_run_checked search issues "$query" --json number \
		--jq '[.[].number | tostring]'
	out=$GH_OUT
	printf '%s\n' "$out"
}

# One gh invocation, never retried. A failed create may still have landed, so it
# exits partial carrying whatever URL was observed rather than claiming the
# write did not happen: a retry here produces duplicate live issues, and a live
# tenant has no undo.
profile_create() {
	github_require_target
	local title='' body_file='' parent='' status=0 out url
	local -a labels=()
	while (($#)); do
		case $1 in
		--title)
			(($# >= 2)) || die "$EXIT_USAGE" usage '--title needs a value'
			title=$2
			shift 2
			;;
		--body-file)
			(($# >= 2)) || die "$EXIT_USAGE" usage '--body-file needs a value'
			body_file=$2
			shift 2
			;;
		--label)
			(($# >= 2)) || die "$EXIT_USAGE" usage '--label needs a value'
			labels+=("$2")
			shift 2
			;;
		--parent)
			(($# >= 2)) || die "$EXIT_USAGE" usage '--parent needs a value'
			# Not a positional, but the same value class: an issue selector
			# reaching gh, and this repo's caller documents it as a number.
			github_require_id "$2" 'parent id'
			parent=$2
			shift 2
			;;
		*) die "$EXIT_USAGE" usage "unknown create argument: $1" ;;
		esac
	done
	[[ -n $title && -n $body_file ]] ||
		die "$EXIT_USAGE" usage 'create needs --title and --body-file'
	[[ -f $body_file && -s $body_file ]] ||
		die "$EXIT_USAGE" usage "body file must be a populated regular file: $body_file"

	local -a args=(issue create --repo "$TRACKER_TARGET" --title "$title"
		--body-file "$body_file")
	if ((${#labels[@]})); then
		local label
		for label in "${labels[@]}"; do args+=(--label "$label"); done
	fi
	[[ -z $parent ]] || args+=(--parent "$parent")

	github_run "${args[@]}" || status=$?
	out=$GH_OUT
	url=$(printf '%s\n' "$out" |
		rg -o 'https://[^/[:space:]]+/[^/[:space:]]+/[^/[:space:]]+/issues/[0-9]+' |
		tail -n 1 || true)
	if ((status != 0)); then
		# A failure that cannot have written is not partial. Reporting an
		# auth or not-found error as "the write may have landed" tells an
		# operator an issue exists when none does.
		local code class
		read -r code class <<<"$(github_classify "$GH_ERR")"
		if [[ $class == auth || $class == not-found ]] && [[ -z $url ]]; then
			die "$code" "$class" "$GH_ERR"
		fi
		jq -Rrn --arg m "$GH_ERR" --arg u "$url" \
			'{error: "partial", message: $m, partial: {url: $u}}' >&2
		exit "$EXIT_PARTIAL"
	fi
	if [[ -z $url ]]; then
		# The write landed; only the identity is unknown. Partial, never a
		# failure -- an operator told "creation failed" re-runs it.
		jq -Rrn --arg m 'created issue URL could not be resolved' \
			'{error: "partial", message: $m, partial: {}}' >&2
		exit "$EXIT_PARTIAL"
	fi
	jq -n --arg u "$url" '{id: ($u | split("/") | last), url: $u}'
}

# Adds and removes travel together. Splitting them breaks the canonical-state
# record's single-active-status invariant in both possible orders: add-then-
# remove leaves two status labels if the second call fails, remove-then-add
# leaves none.
profile_label_edit() {
	github_require_target
	(($# >= 1)) || die "$EXIT_USAGE" usage 'label-edit needs an issue id'
	local id=$1 status=0 out
	github_require_id "$id" 'issue id'
	shift
	local -a args=(issue edit "$id" --repo "$TRACKER_TARGET")
	local -a requested_adds=() requested_removes=()
	while (($#)); do
		case $1 in
		--add)
			(($# >= 2)) || die "$EXIT_USAGE" usage '--add needs a value'
			args+=(--add-label "$2")
			requested_adds+=("$2")
			shift 2
			;;
		--remove)
			(($# >= 2)) || die "$EXIT_USAGE" usage '--remove needs a value'
			args+=(--remove-label "$2")
			requested_removes+=("$2")
			shift 2
			;;
		*) die "$EXIT_USAGE" usage "unknown label-edit argument: $1" ;;
		esac
	done
	github_run "${args[@]}" || status=$?
	out=$GH_OUT
	if ((status != 0)); then
		# partial names what was requested, so a caller can repair rather than
		# guess which half of the delta landed.
		jq -Rrn --arg m "$GH_ERR" \
			--argjson adds "$(printf '%s\n' "${requested_adds[@]+"${requested_adds[@]}"}" |
				jq -Rn '[inputs | select(. != "")]')" \
			--argjson removes "$(printf '%s\n' "${requested_removes[@]+"${requested_removes[@]}"}" |
				jq -Rn '[inputs | select(. != "")]')" \
			'{error: "partial", message: $m,
			  partial: {requested_adds: $adds, requested_removes: $removes}}' >&2
		exit "$EXIT_PARTIAL"
	fi
	printf '{}\n'
}

profile_label_ensure() {
	github_require_target
	(($# >= 3)) || die "$EXIT_USAGE" usage 'label-ensure needs a name, colour and description'
	local name=$1 color=$2 description=$3 status=0 out
	github_run label create "$name" --repo "$TRACKER_TARGET" --color "$color" \
		--description "$description" || status=$?
	out=$GH_OUT
	((status == 0)) && {
		printf '{}\n'
		return 0
	}
	# An already-existing label is the ordinary case, not a failure. gh reports
	# it on stderr, so this reads GH_ERR; masking a no-scope failure as success
	# is what this distinction exists to prevent.
	case $GH_ERR in
	*'already exists'*)
		printf '{}\n'
		return 0
		;;
	esac
	github_die "$GH_ERR"
}

profile_comment_add() {
	github_require_target
	(($# >= 2)) || die "$EXIT_USAGE" usage 'comment-add needs an issue id and a body file'
	local id=$1 body_file=$2 status=0 out
	github_require_id "$id" 'issue id'
	[[ -f $body_file && -s $body_file ]] ||
		die "$EXIT_USAGE" usage "body file must be a populated regular file: $body_file"
	github_run issue comment "$id" --repo "$TRACKER_TARGET" \
		--body-file "$body_file" || status=$?
	out=$GH_OUT
	((status == 0)) || die "$EXIT_PARTIAL" partial "$GH_ERR"
	printf '{}\n'
}

profile_state_set() {
	github_require_target
	(($# >= 2)) || die "$EXIT_USAGE" usage 'state-set needs an issue id and a state'
	local id=$1 state=$2 status=0 out verb
	github_require_id "$id" 'issue id'
	case $state in
	open) verb=reopen ;;
	closed) verb=close ;;
	*) die "$EXIT_USAGE" usage "state must be open or closed: $state" ;;
	esac
	github_run issue "$verb" "$id" --repo "$TRACKER_TARGET" || status=$?
	out=$GH_OUT
	((status == 0)) || die "$EXIT_PARTIAL" partial "$GH_ERR"
	printf '{}\n'
}

# The sub-issues endpoint takes the child's *database* id as an integer, not its
# issue number, and -f would send it as a string. Everywhere else in this
# contract `id` is the issue number, so the id has to be resolved here.
profile_link_parent() {
	github_require_target
	(($# >= 2)) || die "$EXIT_USAGE" usage 'link-parent needs a child and a parent id'
	local child=$1 parent=$2 out child_db_id
	github_require_id "$child" 'child id'
	github_require_id "$parent" 'parent id'
	github_run_checked api "repos/$TRACKER_TARGET/issues/$child" --jq .id
	child_db_id=$GH_OUT
	[[ $child_db_id =~ ^[0-9]+$ ]] ||
		die "$EXIT_TRANSPORT" transport \
			"could not resolve a database id for issue $child"
	github_run_checked api "repos/$TRACKER_TARGET/issues/$parent/sub_issues" \
		-F "sub_issue_id=$child_db_id"
	out=$GH_OUT
	printf '{}\n'
}

# GitHub has no typed dependency edge, so a body line is the record. That is
# exactly why this is profile detail rather than a convention every skill has to
# know: a tracker with native links implements the same operation differently.
profile_link_blocks() {
	github_require_target
	(($# >= 2)) || die "$EXIT_USAGE" usage 'link-blocks needs a blocker and a blocked id'
	local blocker=$1 blocked=$2 body status=0 out='' tmp
	# The blocker is also spliced into the regular expression below.
	github_require_id "$blocker" 'blocker id'
	github_require_id "$blocked" 'blocked id'
	github_run_checked issue view "$blocked" --repo "$TRACKER_TARGET" --json body \
		--jq .body
	body=$GH_OUT
	# \r? because GitHub stores web-authored bodies with CRLF and rg's $ does not
	# match before \r -- without it the guard never fires and every call appends
	# another line. create-verified-issue.sh already does this for its sections.
	# Already linked: return without writing. Skipping the write makes the
	# operation idempotent in the common case and keeps it out of the
	# read-modify-write race entirely.
	if printf '%s\n' "$body" | rg -q "^Blocked by #$blocker\r?\$"; then
		printf '{}\n'
		return 0
	fi
	body="$body
Blocked by #$blocker"
	tmp=$(mktemp)
	printf '%s\n' "$body" >"$tmp"
	github_run issue edit "$blocked" --repo "$TRACKER_TARGET" --body-file "$tmp" ||
		status=$?
	out=$GH_OUT
	rm -f -- "$tmp"
	((status == 0)) || die "$EXIT_PARTIAL" partial "$GH_ERR"
	printf '{}\n'
}
