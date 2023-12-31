// Copyright Istio Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package plugin

const (
	defInterceptRuleMgrType = "iptables"
)

// InterceptRuleMgr configures networking tables (e.g. iptables or nftables) for
// redirecting traffic to an Codesealer proxy.
type InterceptRuleMgr interface {
	Program(podName, netns string, redirect *Redirect) error
}

type InterceptRuleMgrCtor func() InterceptRuleMgr

var InterceptRuleMgrTypes = map[string]InterceptRuleMgrCtor{
	"iptables": IptablesInterceptRuleMgrCtor,
}

// Constructor factory for known types of InterceptRuleMgr's
func GetInterceptRuleMgrCtor(interceptType string) InterceptRuleMgrCtor {
	return InterceptRuleMgrTypes[interceptType]
}

// Constructor for iptables InterceptRuleMgr
func IptablesInterceptRuleMgrCtor() InterceptRuleMgr {
	return newIPTables()
}
